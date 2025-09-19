defmodule Najva.XmppClient do
  use GenServer
  require Logger

  # 	@xmpp_include_path "deps/xmpp/include/xmpp.hrl"
  # 	@record_opts [includes: [@xmpp_include_path]]
  #
  # 	require Record
  # 	Record.defrecordp(
  # 		:jid,
  # 		Record.extract(:jid, from: @xmpp_include_path)
  # 	)
  #
  # 	Record.defrecordp(
  # 		:sasl_mechanisms,
  # 		Record.extract(:sasl_mechanisms, [from: @xmpp_include_path] ++ @record_opts)
  # 	)
  #
  # 	Record.defrecordp(
  # 		:sasl_auth,
  # 		Record.extract(:sasl_auth, [from: @xmpp_include_path] ++ @record_opts)
  # 	)
  #
  # 	Record.defrecordp(
  # 		:sasl_success,
  # 		Record.extract(:sasl_success, [from: @xmpp_include_path] ++ @record_opts)
  # 	)
  #
  # 	Record.defrecordp(
  # 		:sasl_failure,
  # 		Record.extract(:sasl_failure, [from: @xmpp_include_path] ++ @record_opts)
  # 	)
  #
  # 	Record.defrecordp(
  # 		:bind,
  # 		Record.extract(:bind, [from: @xmpp_include_path] ++ @record_opts)
  # 	)
  #
  # 	Record.defrecordp(
  # 		:iq,
  # 		Record.extract(:iq, [from: @xmpp_include_path] ++ @record_opts)
  # 	)
  #
  # 	Record.defrecordp(
  # 		:presence,
  # 		Record.extract(:presence, [from: @xmpp_include_path] ++ @record_opts)
  # 	)
  #
  # 	Record.defrecordp(
  # 		:message,
  # 		Record.extract(:message, [from: @xmpp_include_path] ++ @record_opts)
  # 	)

  @doc "Start the XMPP client. Options: :jid, :password, :host, :port"
  def start_link(opts) when is_list(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    jid = "#{opts[:jid]}/Najva-#{System.os_time(:millisecond)}"

    state = %{
      jid: jid,
      password: opts[:password],
      host: opts[:host],
      port: opts[:port],
      connection_state: :connecting,
      stream_state: :fxml_stream.new(self(), :infinity, [:no_gen_server]),
      socket: nil
    }

    Logger.info("XmppClient: connecting to #{state.host}:#{state.port}")
    send(self(), :connect)
    {:ok, state}
  end

  @impl true
  def handle_info(:connect, state) do
    socket_opts = [:binary, packet: :raw, active: :once, keepalive: true]

    case :gen_tcp.connect(to_charlist(state.host), state.port, socket_opts) do
      {:ok, sock} ->
        Logger.info("XmppClient: tcp connected, revieved socket #{inspect(sock)}")
        new_state = %{state | socket: sock}
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

  @impl true
  def handle_info({:xmlstreamelement, element}, state) do
    Logger.debug("Najva.XmppClient Handled: #{inspect(element)}")
    handle_element(element, state)
  end

  @impl true
  def handle_info({:ssl_closed, socket}, %{socket: socket} = state) do
    Logger.warning("XmppClient: ssl closed")
    {:stop, :normal, state}
  end

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
    Logger.debug("Najva.XmppClient Unhandled: #{inspect(msg)}")
    {:noreply, state}
  end

  defp send_stream_header(state) do
    header =
      "<stream:stream to='#{state.host}' xmlns='jabber:client' xmlns:stream='http://etherx.jabber.org/streams' version='1.0'>"

    send_data(state, header)
  end

  defp parse_and_continue(state, data, transport) do
    new_stream_state = :fxml_stream.parse(state.stream_state, data)

    case transport do
      :ssl -> :ssl.setopts(state.socket, active: :once)
      :tcp -> :inet.setopts(state.socket, active: :once)
    end

    {:noreply, %{state | stream_state: new_stream_state}}
  end

  defp send_data(%{connection_state: :tls_upgraded, socket: sock}, data),
    do: :ssl.send(sock, data)

  defp send_data(%{socket: sock}, data),
    do: :gen_tcp.send(sock, data)

  # defp send_element(state, element) do
  # 	xml = :xmpp.encode(element)
  # 	bin = :fxml.element_to_binary(xml)
  # 	send_data(state, bin)
  # end

  defp handle_element({:xmlstreamstart, "stream:stream", attrs, _children}, state) do
    Logger.info("XmppClient: xml stream started [from: #{attrs[:from]}, id: #{attrs[:id]}]")
    {:noreply, state}
  end

  defp handle_element({:xmlel, "stream:features", attrs, children}, state) do
    Logger.info("XmppClient: received stream features")
    {:stream_features, features} = :xmpp.decode({:xmlel, "stream:features", attrs, children})
    handle_features(features, state)
  end

  defp handle_element({:xmlel, "proceed", _attrs, _children}, state) do
    Logger.info("XmppClient: received TLS proceed, upgrading to TLS")
    handle_starttls_proceed(state)
  end

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

  defp handle_features(features, state) do
    if features[:starttls] do
      Logger.info("XmppClient: STARTTLS supported, initiating...")
      send_data(state, "<starttls xmlns='urn:ietf:params:xml:ns:xmpp-tls'/>")
      {:noreply, %{state | connection_state: :tls_negotiating}}
    else
      Logger.error("XmppClient: STARTTLS not supported or required.")
      {:stop, :tls_not_supported, state}
    end
  end

  defp handle_starttls_proceed(state) do
    Logger.info("XmppClient: TLS negotiation proceeding, upgrading socket...")

    case :ssl.connect(state.socket, [{:active, :once}, {:verify, :verify_none}], 5_000) do
      {:ok, tls_sock} ->
        Logger.info("XmppClient: TLS handshake successful.")
        # When upgrading to TLS, we need to create a new stream state.
        # The :no_gen_server option tells fxml_stream to send messages directly to self()
        new_state = %{
          state
          | socket: tls_sock,
            connection_state: :tls_active,
            stream_state: :fxml_stream.new(self(), :infinity, [:no_gen_server])
        }

        send_stream_header(new_state)
        {:noreply, new_state}

      {:error, reason} ->
        Logger.error("XmppClient: TLS handshake failed: #{inspect(reason)}")
        {:stop, {:tls_handshake_failed, reason}, state}
    end
  end

  defp handle_sasl_success(state) do
    Logger.info("XmppClient: SASL success")
    # After successful auth, we restart the stream.
    new_state = %{
      state
      | stream_state: :fxml_stream.new(self(), :infinity, [:no_gen_server]),
        connection_state: :authenticated
    }

    send_stream_header(new_state)
    {:noreply, new_state}
  end
end
