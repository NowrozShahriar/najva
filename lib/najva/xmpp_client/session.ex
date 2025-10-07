defmodule Najva.XmppClient.Session do
  alias Najva.XmppClient
  require Logger
  require Record

  @xmpp_include_path "deps/xmpp/include/xmpp.hrl"
  # @records_path [from: "deps/xmpp/include/xmpp.hrl", includes: ["deps/xmpp/include/xmpp.hrl"]]

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

  # Step 3, 15, 26
  def send_stream_header(state) do
    header =
      "<stream:stream to='#{state.host}' xmlns='jabber:client' xmlns:stream='http://etherx.jabber.org/streams' version='1.0'>"

    XmppClient.send_data(state, header)
  end

  # Step 10
  def handle_features(features, state) do
    cond do
      # Step 10.5
      features[:starttls] ->
        # Logger.info("XmppClient.Session: STARTTLS supported, initiating...")
        XmppClient.send_data(state, "<starttls xmlns='urn:ietf:params:xml:ns:xmpp-tls'/>")
        {:noreply, %{state | connection_state: :tls_negotiating}}

      # Step 20
      features[:sasl_mechanisms] ->
        # Logger.info("XmppClient.Session: SASL mechanisms available.")
        handle_sasl(features[:sasl_mechanisms], state)

      # Step 31
      Enum.find(features, &match?({:bind, _, _}, &1)) ->
        bind_iq = iq(type: :set, id: "bind_1", sub_els: [bind(resource: state.resource)])
        # Logger.debug("XmppClient.Session: sending bind IQ: #{inspect(bind_iq)}")
        XmppClient.send_element(state, bind_iq)
        {:noreply, state}

      true ->
        Logger.error("XmppClient.Session: STARTTLS not supported or required.")
        {:stop, :tls_not_supported, state}
    end
  end

  # Step 14
  def handle_starttls_proceed(state) do
    # Logger.info("XmppClient.Session: TLS negotiation proceeding, upgrading socket...")
    case :ssl.connect(state.socket, [{:active, :once}, {:verify, :verify_none}], 5_000) do
      {:ok, tls_sock} ->
        # Step 14.5
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
        Logger.error("XmppClient.Session: TLS handshake failed: #{inspect(reason)}")
        {:stop, {:tls_handshake_failed, reason}, state}
    end
  end

  # Step 21
  def handle_sasl(mechanisms, state) do
    if "PLAIN" in mechanisms do
      # Logger.info("XmppClient.Session: PLAIN authentication supported, authenticating...")
      auth_string = Base.encode64("\0#{state.jid}\0#{state.password}")

      XmppClient.send_data(
        state,
        "<auth xmlns='urn:ietf:params:xml:ns:xmpp-sasl' mechanism='PLAIN'>#{auth_string}</auth>"
      )

      {:noreply, state}
    else
      Logger.error("XmppClient.Session: PLAIN authentication not supported.")
      {:stop, :plain_auth_not_supported, state}
    end
  end

  # Step 25
  def handle_sasl_success(state) do
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
  def handle_bind_result(jid, state) do
    # Logger.info("XmppClient.Session: session aquired #{inspect(jid)}\n")
    new_state = %{state | jid: jid}
    # Step 37
    XmppClient.send_element(new_state, presence())
    {:noreply, new_state}
  end
end
