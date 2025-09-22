defmodule Najva.XmppClient do
	use GenServer
	require Logger

	@xmpp_include_path "deps/xmpp/include/xmpp.hrl"
	@record_opts [includes: [@xmpp_include_path]]

	require Record
	Record.defrecordp(
		:jid,
		Record.extract(:jid, from: @xmpp_include_path))

	Record.defrecordp(
		:stream_features,
		Record.extract(:stream_features, [from: @xmpp_include_path] ++ @record_opts))

	Record.defrecordp(
		:sasl_mechanisms,
		Record.extract(:sasl_mechanisms, [from: @xmpp_include_path] ++ @record_opts))

	Record.defrecordp(
		:sasl_auth,
		Record.extract(:sasl_auth, [from: @xmpp_include_path] ++ @record_opts))

	Record.defrecordp(
		:sasl_success,
		Record.extract(:sasl_success, [from: @xmpp_include_path] ++ @record_opts))

	Record.defrecordp(
		:sasl_failure,
		Record.extract(:sasl_failure, [from: @xmpp_include_path] ++ @record_opts))

	Record.defrecordp(
		:bind,
		Record.extract(:bind, [from: @xmpp_include_path] ++ @record_opts))

	Record.defrecordp(
		:iq,
		Record.extract(:iq, [from: @xmpp_include_path] ++ @record_opts))

	Record.defrecordp(
		:presence,
		Record.extract(:presence, [from: @xmpp_include_path] ++ @record_opts))

	Record.defrecordp(
		:message,
		Record.extract(:message, [from: @xmpp_include_path] ++ @record_opts))

	@doc "Start the XMPP client. Options: :jid, :password, :host, :port"
	def start_link(opts) when is_list(opts) do
		GenServer.start_link(__MODULE__, opts, name: __MODULE__)
	end

	@impl true
	def init(opts) do

		{:ok, timestamp} = Timex.now() |> Timex.format("%Y%m%d%H%M%S", :strftime)
		jid = "#{opts[:jid]}/Najva-#{timestamp}"

		# Step 0
		state = %{
			jid: jid,
			password: opts[:password],
			host: opts[:host],
			port: opts[:port],
			connection_state: :connecting,
			stream_state: :fxml_stream.new(self(), :infinity, [:no_gen_server]),
			# The :no_gen_server option tells fxml_stream to send messages directly to self()
			socket: nil
		}

		# Step 1
		Logger.info("XmppClient: connecting to #{state.host}:#{state.port}")
		send(self(), :connect)
		{:ok, state}
	end

	# Step 2
	@impl true
	def handle_info(:connect, state) do
		socket_opts = [:binary, packet: :raw, active: :once, keepalive: true]

		case :gen_tcp.connect(to_charlist(state.host), state.port, socket_opts) do
			{:ok, sock} ->
				Logger.info("XmppClient: tcp connected, revieved socket #{inspect(sock)}")
				new_state = %{state | socket: sock}

				# Step 2.5
				send_stream_header(new_state)
				{:noreply, new_state}

			{:error, reason} ->
				Logger.error("XmppClient: connect error #{inspect(reason)}")
				{:stop, {:tcp_connect_failed, reason}, state}
		end
	end

	@impl true
	def handle_info({:ssl, socket, data}, %{socket: socket} = state),
		do: parse_and_continue(state, data, :ssl)

	# Step 8, 12, 18, 24
	@impl true
	def handle_info({:xmlstreamelement, element}, state) do
		Logger.debug("XmppClient XML element received: #{inspect(element)}")
		handle_element(element, state)
	end

	# Step 7, 17, 23
	@impl true
	def handle_info({:xmlstreamstart, _name, _attrs} = header_response, state) do
		Logger.notice("XmppClient: new XML stream started: #{inspect(header_response)}")
		{:noreply, state}
	end

	@impl true
	def handle_info({:ssl_closed, socket}, %{socket: socket} = state) do
		Logger.warning("XmppClient: ssl closed")
		{:stop, :normal, state}
	end

	# Step 5
	@impl true
	def handle_info({:tcp, socket, data}, %{socket: socket} = state),
		do: parse_and_continue(state, data, :tcp)

	@impl true
	def handle_info({:tcp_closed, socket}, %{socket: socket} = state) do
		Logger.warning("XmppClient: tcp closed")
		{:stop, :normal, state}
	end

	@impl true
	def handle_info(msg, state) do
		Logger.debug("XmppClient UNHANDLED: #{inspect(msg)}")
		{:noreply, state}
	end

	# Step 6
	defp parse_and_continue(state, data, transport) do
		new_stream_state = :fxml_stream.parse(state.stream_state, data)

		case transport do
			:ssl -> :ssl.setopts(state.socket, active: :once)
			:tcp -> :inet.setopts(state.socket, active: :once)
		end

		{:noreply, %{state | stream_state: new_stream_state}}
	end

	# Step 3, 15, 26
	defp send_stream_header(state) do
		header =
			"<stream:stream to='#{state.host}' xmlns='jabber:client' xmlns:stream='http://etherx.jabber.org/streams' version='1.0'>"
		Logger.info("XmppClient: sending stream header")
		send_data(state, header)
	end

	# Step 27
	defp send_data(%{connection_state: :authenticated, socket: sock}, data),
		do: :ssl.send(sock, data)

	# Step 16, 22
	defp send_data(%{connection_state: :tls_active, socket: sock}, data),
		do: :ssl.send(sock, data)

	# Step 4, 11
	defp send_data(%{socket: sock}, data),
		do: :gen_tcp.send(sock, data)

	# defp send_element(state, element) do
	# 	xml = :xmpp.encode(element)
	# 	bin = :fxml.element_to_binary(xml)
	# 	send_data(state, bin) |> IO.inspect(label: "sent element")
	# end

	# Step 9, 19, 25
	defp handle_element({:xmlel, "stream:features", attrs, children}, state) do
		{:stream_features, features} = :xmpp.decode({:xmlel, "stream:features", attrs, children})
		Logger.info("XmppClient: received stream features: #{inspect(features)}")
		handle_features(features, state)
	end

	# Step 13
	defp handle_element({:xmlel, "proceed", _attrs, _children}, state) do
		Logger.info("XmppClient: received TLS proceed, upgrading to TLS")
		handle_starttls_proceed(state)
	end

	# Step 24
	defp handle_element({:xmlel, "success", _attrs, _children}, state) do
		Logger.info("XmppClient: SASL success, restarting stream")
		handle_sasl_success(state)
	end

	defp handle_element({:xmlel, "failure", _attrs, _children}, state) do
		Logger.error("XmppClient: SASL authentication failed")
		{:stop, :sasl_failure, state}
	end

	defp handle_element({:xmlel, "iq", attrs, children}, state) do
		iq = :xmpp.decode({:xmlel, "iq", attrs, children})
		Logger.debug("XmppClient: received IQ: #{inspect(iq)}")
		{:noreply, state}
	end

	defp handle_element({:xmlel, "message", attrs, children}, state) do
		message = :xmpp.decode({:xmlel, "message", attrs, children})
		Logger.debug("XmppClient: received message: #{inspect(message)}")
		{:noreply, state}
	end

	defp handle_element({:xmlel, "presence", attrs, children}, state) do
		presence = :xmpp.decode({:xmlel, "presence", attrs, children})
		Logger.debug("XmppClient: received presence: #{inspect(presence)}")
		{:noreply, state}
	end

	defp handle_element(element, state) do
		Logger.debug("XmppClient: unhandled XML element: #{inspect(element)}")
		{:noreply, state}
	end

	# Step 10
	defp handle_features(features, state) do
		cond do
			# Step 10.5
			features[:starttls] && state.connection_state != :tls_active ->
				Logger.info("XmppClient: STARTTLS supported, initiating...")
				send_data(state, "<starttls xmlns='urn:ietf:params:xml:ns:xmpp-tls'/>")
				{:noreply, %{state | connection_state: :tls_negotiating}}

			# Step 20
			features[:sasl_mechanisms] ->
				Logger.info("XmppClient: SASL mechanisms available.")
				handle_sasl(features[:sasl_mechanisms], state)

			true ->
				Logger.error("XmppClient: STARTTLS not supported or required.")
				{:stop, :tls_not_supported, state}
		end
	end

	# Step 14
	defp handle_starttls_proceed(state) do
		Logger.info("XmppClient: TLS negotiation proceeding, upgrading socket...")
		case :ssl.connect(state.socket, [{:active, :once}, {:verify, :verify_none}], 5_000) do
			{:ok, tls_sock} ->
				Logger.info("XmppClient: TLS handshake successful.")
				# Step 14.5
				# When upgrading to TLS, we need to create a new stream state.
				new_state = %{
					state
					| socket: tls_sock,
						connection_state: :tls_active,
						stream_state: :fxml_stream.new(self(), :infinity, [:no_gen_server])
				}
				# Step 14.6
				send_stream_header(new_state)
				{:noreply, new_state}

			{:error, reason} ->
				Logger.error("XmppClient: TLS handshake failed: #{inspect(reason)}")
				{:stop, {:tls_handshake_failed, reason}, state}
		end
	end

	# Step 21
	defp handle_sasl(mechanisms, state) do
		if "PLAIN" in mechanisms do
			Logger.info("XmppClient: PLAIN authentication supported, authenticating...")
			auth_string = Base.encode64("\0#{state.jid}\0#{state.password}")
			send_data(state, "<auth xmlns='urn:ietf:params:xml:ns:xmpp-sasl' mechanism='PLAIN'>#{auth_string}</auth>")
			{:noreply, state}
		else
			Logger.error("XmppClient: PLAIN authentication not supported.")
			{:stop, :plain_auth_not_supported, state}
		end
	end

	# Step 25
	defp handle_sasl_success(state) do
		Logger.info("XmppClient: SASL success")
		# After successful auth, we restart the stream.
		new_state = %{
			state
			| stream_state: :fxml_stream.new(self(), :infinity, [:no_gen_server]),
				connection_state: :authenticated
		}
		# Step 25.5
		send_stream_header(new_state)
		{:noreply, new_state}
	end
end
