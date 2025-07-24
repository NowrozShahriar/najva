defmodule Najva.XmppClient do
  use GenServer
  require Logger

  # The xmpp library is from Erlang, so we need to include its record definitions to work with them in Elixir.

  @xmpp_include_path "deps/xmpp/include/xmpp.hrl"
  @record_opts [includes: [@xmpp_include_path]]

  require Record
  Record.defrecordp :jid, Record.extract(:jid, from: @xmpp_include_path)
  # All records below are from xmpp_codec.hrl, which includes other files.
  Record.defrecordp :stream_features, Record.extract(:stream_features, [from: @xmpp_include_path] ++ @record_opts)
  Record.defrecordp :starttls, Record.extract(:starttls, [from: @xmpp_include_path] ++ @record_opts)
  Record.defrecordp :starttls_proceed, Record.extract(:starttls_proceed, [from: @xmpp_include_path] ++ @record_opts)
  Record.defrecordp :sasl_failure, Record.extract(:sasl_failure, [from: @xmpp_include_path] ++ @record_opts)
  Record.defrecordp :sasl_success, Record.extract(:sasl_success, [from: @xmpp_include_path] ++ @record_opts)
  Record.defrecordp :sasl_auth, Record.extract(:sasl_auth, [from: @xmpp_include_path] ++ @record_opts)
  Record.defrecordp :iq, Record.extract(:iq, [from: @xmpp_include_path] ++ @record_opts)
  Record.defrecordp :bind, Record.extract(:bind, [from: @xmpp_include_path] ++ @record_opts)
  Record.defrecordp :presence, Record.extract(:presence, [from: @xmpp_include_path] ++ @record_opts)
  Record.defrecordp :message, Record.extract(:message, [from: @xmpp_include_path] ++ @record_opts)
  Record.defrecordp :text, Record.extract(:text, [from: @xmpp_include_path] ++ @record_opts)
  Record.defrecordp :sasl_mechanisms, Record.extract(:sasl_mechanisms, [from: @xmpp_include_path] ++ @record_opts)

  @doc "Starts the XMPP client GenServer."
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    jid_str = "najva_test0@xmpp.social"
    password = "12345678"
    host = "xmpp.social"
    port = 5222

    {:ok, jid} = :jid.from_string(jid_str)

    state = %{
      jid: jid,
      password: password,
      host: host,
      port: port,
      connection_state: :connecting,
      stream_state: :fxml_stream.new(self(), host, []),
      socket: nil
    }

    Logger.info("XMPP client starting. Connecting to #{host}:#{port}...")
    # Connect asynchronously to not block the application start
    send(self(), :connect)
    {:ok, state}
  end

  @impl true
  def handle_info(:connect, state) do
    host_charlist = to_charlist(state.host)
    socket_opts = [:binary, packet: :raw, active: :once, keepalive: true]

    case :gen_tcp.connect(host_charlist, state.port, socket_opts) do
      {:ok, socket} ->
        Logger.info("TCP socket connected. Sending initial stream header.")
        new_state = %{state | socket: socket}
        send_stream_header(new_state)
        {:noreply, new_state}

      {:error, reason} ->
        Logger.error("Failed to connect: #{:inet.format_error(reason)}")
        # You could add retry logic here
        {:stop, {:tcp_connect_failed, reason}, state}
    end
  end

  # Handle raw data from the socket (before and after TLS)
  @impl true
  def handle_info({transport, socket, data}, state)
      when transport in [:tcp, :ssl] and socket == state.socket do
    new_stream_state = :fxml_stream.parse(state.stream_state, data)

    # Set socket options based on transport type
    case state.connection_state do
      :tls_upgraded -> :ssl.setopts(socket, active: :once)
      _ -> :inet.setopts(socket, active: :once)
    end

    {:noreply, %{state | stream_state: new_stream_state}}
  end

  # Handle parsed XML elements from fxml_stream
  @impl true
  def handle_info({:xmlstreamelement, element}, state) do
    handle_element(element, state)
  end

  @impl true
  def handle_info({:xmlstreamstart, _name, _attrs}, state) do
    Logger.debug("Received stream start")
    {:noreply, state}
  end

  @impl true
  def handle_info({:xmlstreamend, _name}, state) do
    Logger.info("Stream ended. Closing connection.")
    {:stop, :normal, state}
  end

  # Handle connection closed
  @impl true
  def handle_info({transport, socket}, state)
      when transport in [:tcp_closed, :ssl_closed] and socket == state.socket do
    Logger.warning("Socket closed.")
    {:stop, :normal, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.warning("Unhandled message in XmppClient: #{inspect(msg)}")
    {:noreply, state}
  end

  # Private helpers for sending data

  defp send_data(state, data) do
    case state.connection_state do
      :tls_upgraded -> :ssl.send(state.socket, data)
      _ -> :gen_tcp.send(state.socket, data)
    end
  end

  defp send_element(state, element) do
    xml_element = :xmpp.encode(element)
    data = :fxml.element_to_binary(xml_element)
    send_data(state, data)
  end

  defp send_stream_header(state) do
    header = :fxml.stream_header(state.host)
    send_data(state, header)
  end

  # Main logic for handling different XMPP elements

  defp handle_element(element, state) do
    case element do
      # 1. Server sends features. We check for STARTTLS.
      stream_features(sub_els: features) ->
        cond do
          Enum.any?(features, &match?(starttls(), &1)) ->
            Logger.info("Server supports STARTTLS. Upgrading connection...")
            send_element(state, starttls())
            {:noreply, %{state | connection_state: :starttls_sent}}

          :xmpp.find_subtag(element, :mechanisms) ->
            Logger.info("Secure connection established. Authenticating...")
            do_sasl_auth(state, element)

          :xmpp.find_subtag(element, :bind) ->
            Logger.info("Authenticated. Binding resource...")
            do_bind(state)

          true ->
            Logger.debug("Received features but no supported features found")
            {:noreply, state}
        end

      # 2. Server agrees to STARTTLS.
      element when state.connection_state == :starttls_sent ->
        case element do
          starttls_proceed() ->
            Logger.info("Proceeding with TLS handshake.")
            # Important: verify: :verify_peer and a CA trust store should be used in production.
            # For this test, we use :verify_none.
            case :ssl.connect(state.socket, [{:active, :once}, {:verify, :verify_none}]) do
              {:ok, tls_socket} ->
                new_stream_state = :fxml_stream.new(self(), state.host, [])
                new_state = %{state | socket: tls_socket, connection_state: :tls_upgraded, stream_state: new_stream_state}
                send_stream_header(new_state)
                {:noreply, new_state}

              {:error, reason} ->
                Logger.error("TLS upgrade failed: #{inspect(reason)}")
                {:stop, {:tls_failed, reason}, state}
            end

          _ ->
            Logger.warning("Expected STARTTLS proceed but got: #{inspect(element)}")
            {:noreply, state}
        end

      # 3. SASL authentication was successful.
      sasl_success() ->
        Logger.info("SASL authentication successful.")
        new_stream_state = :fxml_stream.new(self(), state.host, [])
        send_stream_header(%{state | stream_state: new_stream_state})
        {:noreply, %{state | stream_state: new_stream_state}}

      # 4. Resource binding was successful.
      iq(type: :result, sub_els: sub_els) ->
        case Enum.find(sub_els, &match?(bind(), &1)) do
          bind(jid: full_jid) when full_jid != :undefined ->
            jid_string = jid(full_jid) |> :jid.to_string() |> to_string()
            Logger.info("Resource bound successfully: #{jid_string}")
            send_initial_presence(state)
            {:noreply, %{state | connection_state: :session_started}}

          _ ->
            Logger.debug("Received IQ result but not for bind")
            {:noreply, state}
        end

      # 5. We are now fully connected and can receive messages.
      message(from: from, sub_els: sub_els) when from != :undefined ->
        from_jid = jid(from) |> :jid.to_string() |> to_string()
        body = :xmpp.get_text(sub_els) |> to_string()
        Logger.info("Received message from #{from_jid}: #{body}")
        # Here we will eventually broadcast to the LiveView
        {:noreply, state}

      presence() ->
        # We can handle presence updates here (e.g., contact going online/offline)
        Logger.debug("Received presence stanza.")
        {:noreply, state}

      sasl_failure() ->
        Logger.error("XMPP authentication failed.")
        {:stop, :auth_failed, state}

      other ->
        Logger.debug("Received unhandled XMPP element: #{inspect(other)}")
        {:noreply, state}
    end
  end

  defp do_sasl_auth(state, stream_features() = stream_features_element) do
    case :xmpp.get_subtag(stream_features_element, :mechanisms) do
      sasl_mechanisms(list: mechanisms) ->
        # We'll use PLAIN for simplicity. SCRAM is more secure.
        if "PLAIN" in mechanisms do
          auth_str = <<0, state.jid.user::binary, 0, state.password::binary>>
          auth_data = Base.encode64(auth_str)
          auth_el = sasl_auth(mechanism: "PLAIN", text: auth_data)
          send_element(state, auth_el)
          {:noreply, state}
        else
          Logger.error("Server does not support PLAIN authentication. Available: #{inspect(mechanisms)}")
          {:stop, :no_plain_auth, state}
        end

      nil ->
        Logger.error("No SASL mechanisms found in stream features")
        {:stop, :no_sasl_mechanisms, state}

      other ->
        Logger.error("Unexpected SASL mechanisms format: #{inspect(other)}")
        {:stop, :invalid_sasl_mechanisms, state}
    end
  end

  defp do_bind(state) do
    # We can specify a resource, or let the server assign one.
    # Let's let the server assign one.
    bind_el = bind()
    iq_id = :crypto.strong_rand_bytes(8) |> Base.encode16()
    iq_el = iq(type: :set, id: iq_id, sub_els: [bind_el])
    send_element(state, iq_el)
    {:noreply, state}
  end

  defp send_initial_presence(state) do
    presence_el = presence()
    send_element(state, presence_el)
  end
end
