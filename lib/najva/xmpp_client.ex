defmodule Najva.XmppClient do
	use GenServer
	require Logger

	@xmpp_include_path "deps/xmpp/include/xmpp.hrl"
	@record_opts [includes: [@xmpp_include_path]]

	require Record

	Record.defrecordp(
		:jid,
		Record.extract(:jid, from: @xmpp_include_path)
		# defrecordp :jid, [
		# 	user: "",        # binary(), default: ""
		# 	server: "",      # binary(), default: ""
		# 	resource: "",    # binary(), default: ""
		# 	luser: "",       # binary(), default: ""
		# 	lserver: "",     # binary(), default: ""
		# 	lresource: ""    # binary(), default: ""
		# ]
	)

	# Record.defrecordp(
	# 	:sasl_mechanisms,
	# 	Record.extract(:sasl_mechanisms, [from: @xmpp_include_path] ++ @record_opts))

	# Record.defrecordp(
	# 	:sasl_auth,
	# 	Record.extract(:sasl_auth, [from: @xmpp_include_path] ++ @record_opts))

	# Record.defrecordp(
	# 	:sasl_success,
	# 	Record.extract(:sasl_success, [from: @xmpp_include_path] ++ @record_opts))

	# Record.defrecordp(
	# 	:sasl_failure,
	# 	Record.extract(:sasl_failure, [from: @xmpp_include_path] ++ @record_opts))

	Record.defrecordp(
		:bind,
		Record.extract(:bind, [from: @xmpp_include_path] ++ @record_opts)
		# defrecord :bind, [
		# 	jid: nil,
		# 	resource: ""
		# ]
	)

	Record.defrecordp(
		:iq,
		Record.extract(:iq, [from: @xmpp_include_path] ++ @record_opts)
		# defrecordp :iq, [
		# 	id: "",                # binary(), default: ""
		# 	type: nil,             # atom(), e.g. :get, :set, :result, :error
		# 	lang: "",              # binary(), default: ""
		# 	from: nil,             # nil or JID struct
		# 	to: nil,               # nil or JID struct
		# 	sub_els: [],           # list of xmpp_element or xmlel
		# 	meta: %{}              # map, default: empty map
		# ]
	)

	Record.defrecordp(
		:presence,
		Record.extract(:presence, [from: @xmpp_include_path] ++ @record_opts)
		# defrecordp :presence, [
		# id: "",                # binary(), default: ""
		# type: :available,      # atom(), default: :available
		# lang: "",              # binary(), default: ""
		# from: nil,             # nil or JID struct
		# to: nil,               # nil or JID struct
		# show: nil,             # nil or :away | :chat | :dnd | :xa
		# status: [],            # list of text records
		# priority: nil,         # nil or integer
		# sub_els: [],           # list of xmpp_element or xmlel
		# meta: %{}              # map, default: empty map
		# ]
	)

	Record.defrecordp(
		:message,
		Record.extract(:message, [from: @xmpp_include_path] ++ @record_opts)
		# defrecordp :message, [
		#   id: "",                # binary(), default: ""
		#   type: :normal,         # atom(), default: :normal
		#   lang: "",              # binary(), default: ""
		#   from: nil,             # nil or JID struct
		#   to: nil,               # nil or JID struct
		#   subject: [],           # list of text records
		#   body: [],              # list of text records
		#   thread: nil,           # nil or message_thread
		#   sub_els: [],           # list of xmpp_element or xmlel
		#   meta: %{}              # map, default: empty map
		# ]
	)

	@doc "Start the XMPP client. Options: :jid, :password, :host, :port"
	def start_link(opts) when is_list(opts) do
		GenServer.start_link(__MODULE__, opts, name: __MODULE__)
	end

	@impl true
	def init(opts) do
		# {:ok, timestamp} = Timex.now() |> Timex.format("%y%m%d%H%M%S", :strftime)
		resource = "/Najva-#{System.os_time(:second) |> Integer.to_string(36)}"

		# Step 0
		state = %{
			jid: opts[:jid],
			password: opts[:password],
			resource: resource,
			host: opts[:host],
			port: opts[:port],
			connection_state: :connecting,
			stream_state: :fxml_stream.new(self(), :infinity, [:no_gen_server]),
			# The :no_gen_server option tells fxml_stream to send messages directly to self()
			socket: nil
		}

		# Step 1
		# Logger.info("XmppClient: connecting to #{state.host}:#{state.port}")
		send(self(), :connect)
		{:ok, state}
	end

	# Step 2
	@impl true
	def handle_info(:connect, state) do
		socket_opts = [:binary, packet: :raw, active: :once, keepalive: true]

		case :gen_tcp.connect(to_charlist(state.host), state.port, socket_opts) do
			{:ok, sock} ->
				# Logger.info("XmppClient: tcp connected, revieved socket #{inspect(sock)}")
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

	# Step 8, 12, 18, 29, 34
	@impl true
	def handle_info({:xmlstreamelement, element}, state) do
		# Logger.info("XmppClient XML element received: #{:xmpp.decode(element) |> inspect()}")
		handle_element(element, state)
	end

	# Step 7, 17, 28
	@impl true
	def handle_info({:xmlstreamstart, _name, _attrs}, state) do
		# Logger.notice("XmppClient: new XML stream started: #{inspect(header_response)}")
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

		# Logger.info("XmppClient: sending stream header")
		send_data(state, header)
	end

	# Step 27, 33
	defp send_data(%{connection_state: :authenticated, socket: sock}, data),
		do: :ssl.send(sock, data) |> IO.inspect(label: "sent data")

	# Step 16, 22
	defp send_data(%{connection_state: :tls_active, socket: sock}, data),
		do: :ssl.send(sock, data)

	# Step 4, 11
	defp send_data(%{socket: sock}, data),
		do: :gen_tcp.send(sock, data)

	# Step 32
	defp send_element(state, element) do
		xmlel = :xmpp.encode(element)
		xml = :fxml.element_to_binary(xmlel)
		Logger.debug("XmppClient: sending element: #{inspect(xml)}")
		send_data(state, xml)
	end

	# Step 9, 19, 30
	defp handle_element({:xmlel, "stream:features", attrs, children}, state) do
		{:stream_features, features} = :xmpp.decode({:xmlel, "stream:features", attrs, children})
		Logger.info("XmppClient: received stream features: #{inspect(features)}")
		handle_features(features, state)
	end

	# Step 13
	defp handle_element({:xmlel, "proceed", _attrs, _children}, state) do
		# Logger.info("XmppClient: received TLS proceed, upgrading to TLS")
		handle_starttls_proceed(state)
	end

	# Step 24
	defp handle_element({:xmlel, "success", _attrs, _children}, state) do
		# Logger.info("XmppClient: SASL success")
		handle_sasl_success(state)
	end

	defp handle_element({:xmlel, "failure", _attrs, _children}, state) do
		Logger.error("XmppClient: SASL authentication failed")
		{:stop, :sasl_failure, state}
	end

	# Step 35
	defp handle_element({:xmlel, "iq", attrs, children}, state) do
		iq = :xmpp.decode({:xmlel, "iq", attrs, children})
		Logger.info("XmppClient: received IQ: #{inspect(iq)}")

		case iq do
			iq(type: :result, sub_els: [bind(jid: jid)]) ->
				handle_bind_result(jid(jid), state)
			# iq(type: :result, sub_els: sub_els) ->
			# 	if bind = Enum.find(sub_els, &match?({:bind, _, _}, &1)) do
			# 		handle_bind_result(bind(bind, :jid), state)
			# 	end
		end

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
			features[:starttls] ->
				# Logger.info("XmppClient: STARTTLS supported, initiating...")
				send_data(state, "<starttls xmlns='urn:ietf:params:xml:ns:xmpp-tls'/>")
				{:noreply, %{state | connection_state: :tls_negotiating}}

			# Step 20
			features[:sasl_mechanisms] ->
				# Logger.info("XmppClient: SASL mechanisms available.")
				handle_sasl(features[:sasl_mechanisms], state)

			# Step 31
			Enum.find(features, &match?({:bind, _, _}, &1)) ->
				Logger.info("XmppClient: Resource binding available, binding...")
				bind_iq = iq(type: :set, id: "bind_1", sub_els: [bind(resource: state.resource)])
				# Logger.debug("XmppClient: sending bind IQ: #{inspect(bind_iq)}")
				send_element(state, bind_iq)
				{:noreply, state}

			true ->
				Logger.error("XmppClient: STARTTLS not supported or required.")
				{:stop, :tls_not_supported, state}
		end
	end

	# Step 14
	defp handle_starttls_proceed(state) do
		# Logger.info("XmppClient: TLS negotiation proceeding, upgrading socket...")
		case :ssl.connect(state.socket, [{:active, :once}, {:verify, :verify_none}], 5_000) do
			{:ok, tls_sock} ->
				# Logger.info("XmppClient: TLS handshake successful.")
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
			# Logger.info("XmppClient: PLAIN authentication supported, authenticating...")
			auth_string = Base.encode64("\0#{state.jid}\0#{state.password}")

			send_data(
				state,
				"<auth xmlns='urn:ietf:params:xml:ns:xmpp-sasl' mechanism='PLAIN'>#{auth_string}</auth>"
			)

			{:noreply, state}
		else
			Logger.error("XmppClient: PLAIN authentication not supported.")
			{:stop, :plain_auth_not_supported, state}
		end
	end

	# Step 25
	defp handle_sasl_success(state) do
		Logger.info("XmppClient: authenticated, restarting stream...")
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

	# Step 36
	defp handle_bind_result(jid, state) do
		Logger.info("XmppClient: Resource bound: #{inspect(jid)}")
		new_state = %{state | jid: jid}
		# Step 37: Send initial presence to signal we are online
		send_element(new_state, presence())
		{:noreply, new_state}
	end
end
