defmodule Najva.XmppClient do
  use GenServer
  alias Najva.XmppClient.Session
  require Logger
  require Record

  @xmpp_include_path "deps/xmpp/include/xmpp.hrl"

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

  Record.defrecordp(
    :bind,
    Record.extract(:bind, from: @xmpp_include_path)
    # defrecord :bind, [
    # 	jid: nil,
    # 	resource: ""
    # ]
  )

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
    :message,
    Record.extract(:message, from: @xmpp_include_path)
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
        Session.send_stream_header(new_state)
        {:noreply, new_state}

      {:error, reason} ->
        Logger.error("XmppClient: connect error #{inspect(reason)}")
        {:stop, {:tcp_connect_failed, reason}, state}
    end
  end

  @impl true
  def handle_info({:ssl, socket, data}, %{socket: socket} = state) do
    Logger.debug(data)
    parse_and_continue(state, data, :ssl)
  end

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

  # Step 27, 33
  def send_data(%{connection_state: :authenticated, socket: sock}, data),
    do: :ssl.send(sock, data)

  # |> IO.inspect(label: "sent data")

  # Step 16, 22
  def send_data(%{connection_state: :tls_active, socket: sock}, data),
    do: :ssl.send(sock, data)

  # Step 4, 11
  def send_data(%{socket: sock}, data),
    do: :gen_tcp.send(sock, data)

  # Step 32
  def send_element(state, record) do
    xmlel = :xmpp.encode(record)
    xml = :fxml.element_to_binary(xmlel)
    # Logger.debug("XmppClient: sending element: #{inspect(xml)}")
    send_data(state, xml)
  end

  # Step 9, 19, 30
  def handle_element({:xmlel, "stream:features", attrs, children}, state) do
    {:stream_features, features} = :xmpp.decode({:xmlel, "stream:features", attrs, children})
    # Logger.info("XmppClient: received stream features: #{inspect(features)}")
    Session.handle_features(features, state)
  end

  # Step 13
  def handle_element({:xmlel, "proceed", _attrs, _children}, state) do
    # Logger.info("XmppClient: received TLS proceed, upgrading to TLS")
    Session.handle_starttls_proceed(state)
  end

  # Step 24
  def handle_element({:xmlel, "success", _attrs, _children}, state) do
    # Logger.info("XmppClient: SASL success")
    Session.handle_sasl_success(state)
  end

  def handle_element({:xmlel, "failure", _attrs, _children}, state) do
    Logger.error("XmppClient: SASL authentication failed")
    {:stop, :sasl_failure, state}
  end

  # Step 35
  def handle_element({:xmlel, "iq", attrs, children}, state) do
    iq = :xmpp.decode({:xmlel, "iq", attrs, children})
    # Logger.info("XmppClient: received IQ: #{inspect(iq)}")

    case iq do
      iq(type: :result, sub_els: [bind(jid: jid)]) ->
        Session.handle_bind_result(jid(jid), state)
    end

    {:noreply, state}
  end

  def handle_element({:xmlel, "message", _attrs, _children}, state) do
    # message = :xmpp.decode({:xmlel, "message", attrs, children})
    # Logger.debug("XmppClient: received message: #{inspect(message)}")
    {:noreply, state}
  end

  def handle_element({:xmlel, "presence", _attrs, _children}, state) do
    # presence = :xmpp.decode({:xmlel, "presence", attrs, children})
    # Logger.debug("XmppClient: received presence: #{inspect(presence)}")
    {:noreply, state}
  end

  def handle_element(element, state) do
    Logger.debug("XmppClient: unhandled XML element: #{inspect(element)}")
    {:noreply, state}
  end
end
