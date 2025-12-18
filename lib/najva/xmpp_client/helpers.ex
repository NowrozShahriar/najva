defmodule Najva.XmppClient.Helpers do
  require Logger
  require Record
  alias Najva.XmppClient.Encryption
  @xmpp_include_path "deps/xmpp/include/xmpp.hrl"

  Record.defrecordp(
    :iq,
    Record.extract(:iq, from: @xmpp_include_path)
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
    :bind,
    Record.extract(:bind, from: @xmpp_include_path)
    # defrecord :bind, [
    # 	jid: nil,
    # 	resource: ""
    # ]
  )

  Record.defrecordp(
    :presence,
    Record.extract(:presence, from: @xmpp_include_path)
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

  def send_element(state, record) do
    xmlel = :xmpp.encode(record)
    xml = :fxml.element_to_binary(xmlel)
    send_data(state, xml)
  end

  def send_data(state, data) do
    case state.connection_state do
      :bound -> send_ssl(state.socket, data)
      :authenticated -> send_ssl(state.socket, data)
      :tls_active -> send_ssl(state.socket, data)
      :connecting -> send_tcp(state.socket, data)
    end
  end

  def parse_and_continue(state, data, transport) do
    new_stream_state = :fxml_stream.parse(state.stream_state, data)

    case transport do
      :ssl -> :ssl.setopts(state.socket, active: :once)
      :tcp -> :inet.setopts(state.socket, active: :once)
    end

    if new_stream_state == state.stream_state do
      {:noreply, state}
    else
      {:noreply, %{state | stream_state: new_stream_state}}
    end
  end

  def send_stream_header(state) do
    send_data(
      state,
      "<stream:stream to='#{state.host}' xmlns='jabber:client' xmlns:stream='http://etherx.jabber.org/streams' version='1.0'>"
    )
  end

  def handle_features(features, state) do
    cond do
      features[:starttls] ->
        # Logger.info("XmppClient.Session: STARTTLS supported, initiating...")
        send_data(state, "<starttls xmlns='urn:ietf:params:xml:ns:xmpp-tls'/>")
        {:noreply, %{state | connection_state: :tls_negotiating}}

      features[:sasl_mechanisms] ->
        # Logger.info("XmppClient.Session: SASL mechanisms available.")
        handle_sasl(features[:sasl_mechanisms], state)

      Enum.find(features, &match?({:bind, _, _}, &1)) ->
        bind_iq = iq(type: :set, id: "bind_1", sub_els: [bind(resource: state.resource)])
        # Logger.debug("XmppClient.Session: sending bind IQ: #{inspect(bind_iq)}")
        send_element(state, bind_iq)
        {:noreply, state}

      true ->
        Logger.error("XmppClient.Session: STARTTLS not supported or required.")
        {:stop, :tls_not_supported, state}
    end
  end

  def handle_starttls_proceed(state) do
    # Logger.info("XmppClient.Session: TLS negotiation proceeding, upgrading socket...")
    case :ssl.connect(state.socket, [{:active, :once}, {:verify, :verify_none}], 5_000) do
      {:ok, tls_sock} ->
        new_state = %{
          state
          | socket: tls_sock,
            connection_state: :tls_active,
            stream_state: :fxml_stream.new(self(), :infinity, [:no_gen_server])
        }

        send_stream_header(new_state)
        {:noreply, new_state}

      {:error, reason} ->
        Logger.error("XmppClient.Session: TLS handshake failed: #{inspect(reason)}")
        {:stop, {:tls_handshake_failed, reason}, state}
    end
  end

  def handle_sasl(mechanisms, state) do
    if "PLAIN" in mechanisms do
      [username | _] = String.split(state.jid, "@")
      # Logger.info("XmppClient.Session: PLAIN authentication supported, authenticating...")
      auth_string = Base.encode64("\0#{username}\0#{state.password}")

      send_data(
        state,
        "<auth xmlns='urn:ietf:params:xml:ns:xmpp-sasl' mechanism='PLAIN'>#{auth_string}</auth>"
      )

      {:noreply, state}
    else
      Logger.error("XmppClient.Session: PLAIN authentication not supported.")
      {:stop, :plain_auth_not_supported, state}
    end
  end

  def handle_sasl_success(state) do
    # After successful auth, we restart the stream.
    new_state = %{
      state
      | stream_state: :fxml_stream.new(self(), :infinity, [:no_gen_server]),
        connection_state: :authenticated
    }

    send_stream_header(new_state)
    {:noreply, new_state}
  end

  def handle_bind_result(jid, state) do
    # Logger.info("XmppClient.Session: session aquired #{inspect(jid)}\n")
    new_state = %{state | jid: jid, connection_state: :bound}

    # Notify caller if one is waiting
    if state.caller_pid do
      case Encryption.generate_and_update_key(state.jid) do
        {:ok, key} ->
          encrypted_password = Encryption.encrypt(state.password, key)
          send(state.caller_pid, {:connection_complete, encrypted_password})

        {:error, reason} ->
          send(state.caller_pid, {:connection_failed, reason})
      end
    end

    send_element(new_state, presence())
    {:noreply, new_state}
  end

  defp send_ssl(socket, data) do
    case :ssl.send(socket, data) do
      :ok ->
        Logger.debug("XmppClient: sent #{inspect(data)}")

      {:error, reason} ->
        Logger.error("XmppClient: ssl send error #{inspect(reason)}")
    end
  end

  defp send_tcp(socket, data) do
    case :gen_tcp.send(socket, data) do
      :ok ->
        Logger.warning("XmppClient: sent with tcp #{inspect(data)}")

      {:error, reason} ->
        Logger.error("XmppClient: tcp send error #{inspect(reason)}")
    end
  end
end
