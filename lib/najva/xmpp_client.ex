defmodule Najva.XmppClient do
  use GenServer
  alias Najva.XmppClient.Session
  require Logger
  require Record

  @xmpp_include_path "deps/xmpp/include/xmpp.hrl"

  Record.defrecordp(:jid, Record.extract(:jid, from: @xmpp_include_path))
  # defrecordp :jid, [
  # 	user: "",        # binary(), default: ""
  # 	server: "",      # binary(), default: ""
  # 	resource: "",    # binary(), default: ""
  # 	luser: "",       # binary(), default: ""
  # 	lserver: "",     # binary(), default: ""
  # 	lresource: ""    # binary(), default: ""
  # ]

  Record.defrecordp(:iq, Record.extract(:iq, from: @xmpp_include_path))
  # defrecordp :iq, [
  # 	id: "",                # binary(), default: ""
  # 	type: nil,             # atom(), e.g. :get, :set, :result, :error
  # 	lang: "",              # binary(), default: ""
  # 	from: nil,             # nil or JID struct
  # 	to: nil,               # nil or JID struct
  # 	sub_els: [],           # list of xmpp_element or xmlel
  # 	meta: %{}              # map, default: empty map
  # ]

  Record.defrecordp(:bind, Record.extract(:bind, from: @xmpp_include_path))
  # defrecord :bind, [
  # 	jid: nil,
  # 	resource: ""
  # ]

  Record.defrecordp(:message, Record.extract(:message, from: @xmpp_include_path))
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

  Record.defrecordp(:mam_query, Record.extract(:mam_query, from: @xmpp_include_path))
  # defrecordp :mam_query, [
  #   xmlns: "",                # binary(), default: ""
  #   id: "",                   # binary(), default: ""
  #   start: nil,               # nil or erlang:timestamp()
  #   end: nil,                 # nil or erlang:timestamp()
  #   with: nil,                # nil or JID record
  #   withtext: nil,            # nil or binary()
  #   rsm: nil,                 # nil or rsm_set record
  #   flippage: false,          # boolean(), default: false
  #   xdata: nil                # nil or xdata record
  # ]

  Record.defrecordp(:rsm_set, Record.extract(:rsm_set, from: @xmpp_include_path))
  # defrecordp :rsm_set, [
  # 	after: nil,    # nil or binary()
  # 	before: nil,   # nil or binary()
  # 	count: nil,    # nil or non_neg_integer()
  # 	first: nil,    # nil or rsm_first record
  # 	index: nil,    # nil or non_neg_integer()
  # 	last: nil,     # nil or binary()
  # 	max: nil       # nil or non_neg_integer()
  # ]

  Record.defrecord(:mam_fin, Record.extract(:mam_fin, from: @xmpp_include_path))
  # defrecordp :mam_fin, [
  # 	xmlns: "",        # binary(), default: ""
  # 	id: "",           # binary(), default: ""
  # 	rsm: nil,         # nil or rsm_set record
  # 	stable: "false",  # "false", "true", or nil (was 'undefined' in Erlang)
  # 	complete: "false" # "false", "true", or nil (was 'undefined' in Erlang)
  # ]

  @doc "Start the XMPP client. Options: :jid, :password, :host, :port"
  def start_link(opts) when is_list(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    resource = "Najva-#{System.os_time(:second) |> Integer.to_string(36)}"
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

  @impl true
  def handle_info(msg, state) do
    case msg do
      # Step 2
      :connect ->
        socket_opts = [:binary, packet: :raw, active: :once, keepalive: true]

        case :gen_tcp.connect(to_charlist(state.host), state.port, socket_opts) do
          {:ok, sock} ->
            # Logger.info("XmppClient: tcp connected, revieved socket #{inspect(sock)}")
            new_state = %{state | socket: sock}
            Session.send_stream_header(new_state)
            {:noreply, new_state}

          {:error, reason} ->
            Logger.error("XmppClient: connect error #{inspect(reason)}")
            {:stop, {:tcp_connect_failed, reason}, state}
        end

      {:ssl, socket, data} when socket == state.socket ->
        # Logger.info("XmppClient: received #{inspect(data)}\n")
        parse_and_continue(state, data, :ssl)

      # Step 8, 12, 18, 29, 34
      {:xmlstreamelement, element} ->
        Logger.info("XmppClient XML element received: #{Fxmap.decode(element) |> inspect()}\n")
        handle_element(element, state)

      # Step 7, 17, 28
      {:xmlstreamstart, _name, _attrs} ->
        # Logger.notice("XmppClient: new XML stream started: #{inspect(header_response)}")
        {:noreply, state}

      {:ssl_closed, socket} when socket == state.socket ->
        Logger.warning("XmppClient: ssl closed")
        {:stop, :normal, state}

      # Step 5
      {:tcp, socket, data} when socket == state.socket ->
        Logger.warning("XmppClient: tcp received #{inspect(data)}\n")
        parse_and_continue(state, data, :tcp)

      {:tcp_closed, socket} when socket == state.socket ->
        Logger.warning("XmppClient: tcp closed")
        {:stop, :normal, state}

      _ ->
        Logger.debug("XmppClient UNHANDLED: #{inspect(msg)}")
        {:noreply, state}
    end
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

  # Step 4, 11, 16, 22, 27, 33
  def send_data(state, data) do
    case state.connection_state do
      conn_state when conn_state in [:authenticated, :tls_active] ->
        case :ssl.send(state.socket, data) do
          :ok ->
            Logger.debug("XmppClient: sent #{inspect(data)}")

          {:error, reason} ->
            Logger.error("XmppClient: ssl send error #{inspect(reason)}")
        end

      _ ->
        case :gen_tcp.send(state.socket, data) do
          :ok ->
            Logger.warning("XmppClient: sent with tcp #{inspect(data)}")

          {:error, reason} ->
            Logger.error("XmppClient: tcp send error #{inspect(reason)}")
        end
    end
  end

  # Step 32
  def send_element(state, record) do
    xmlel = :xmpp.encode(record)
    xml = :fxml.element_to_binary(xmlel)
    send_data(state, xml)
  end

  # Step 35
  def handle_element({:xmlel, "iq", attrs, children}, state) do
    iq = :xmpp.decode({:xmlel, "iq", attrs, children})
    # Logger.info("XmppClient: received IQ: #{inspect(iq)}")
    case iq do
      # Bind result
      iq(type: :result, sub_els: [bind(jid: jid)]) ->
        Session.handle_bind_result(jid(jid), state)

      _ ->
        Logger.debug("XmppClient: unhandled IQ: #{inspect(iq)}")
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
    case element do
      # Step 9, 19, 30
      {:xmlel, "stream:features", attrs, children} ->
        {:stream_features, features} = :xmpp.decode({:xmlel, "stream:features", attrs, children})
        # Logger.info("XmppClient: received stream features: #{inspect(features)}")
        Session.handle_features(features, state)

      # Step 13
      {:xmlel, "proceed", _, _} ->
        # Logger.info("XmppClient: received TLS proceed, upgrading to TLS")
        Session.handle_starttls_proceed(state)

      # Step 24
      {:xmlel, "success", _, _} ->
        # Logger.info("XmppClient: SASL success")
        Session.handle_sasl_success(state)

      {:xmlel, "failure", _, _} ->
        Logger.error("XmppClient: SASL authentication failed")
        {:stop, :sasl_failure, state}

      _ ->
        Logger.debug("XmppClient: unhandled XML element: #{inspect(element)}")
        {:noreply, state}
    end
  end
end
