defmodule Najva.XmppClient do
  use GenServer
  import Najva.XmppClient.Helpers
  require Logger
  alias Phoenix.PubSub
  require Record
  @xmpp_include_path "deps/xmpp/include/xmpp.hrl"
  @ping_interval 59_000

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
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: {:global, opts[:jid]})
  end

  @impl true
  def init(opts) do
    # Step 0
    state = %{
      jid: opts[:jid],
      password: opts[:password],
      resource: "Najva",
      host: String.split(opts[:jid], "@") |> Enum.at(1),
      connection_state: :connecting,
      stream_state: :fxml_stream.new(self(), :infinity, [:no_gen_server]),
      # The :no_gen_server option tells fxml_stream to send messages directly to self()
      socket: nil,
      chat_map: %{}
    }

    # Step 1
    # Logger.info("XmppClient: connecting to #{state.host}")
    send(self(), :connect)
    {:ok, state}
  end

  @impl true
  def handle_info(msg, state) do
    case msg do
      # Step 2
      :connect ->
        socket_opts = [:binary, packet: :raw, active: :once, keepalive: true]

        case :gen_tcp.connect(to_charlist(state.host), 5222, socket_opts) do
          {:ok, sock} ->
            # Logger.info("XmppClient: tcp connected, revieved socket #{inspect(sock)}")
            new_state = %{state | socket: sock}
            send_stream_header(new_state)
            {:noreply, new_state}

          {:error, reason} ->
            Logger.error("XmppClient: connect error to #{state.host} - #{inspect(reason)}")
            {:stop, {:tcp_connect_failed, reason}, state}
        end

      {:ssl, socket, data} when socket == state.socket ->
        # Logger.info("XmppClient: XML received\n#{inspect(data)}\n")
        parse_and_continue(state, data, :ssl)

      # Step 8, 12, 18, 29, 34
      {:xmlstreamelement, element} ->
        # Logger.info("XmppClient XML element received:\n#{inspect(element)}\n")
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
        # Logger.warning("XmppClient: tcp received #{inspect(data)}\n")
        parse_and_continue(state, data, :tcp)

      {:tcp_closed, socket} when socket == state.socket ->
        Logger.warning("XmppClient: tcp closed")
        {:stop, :normal, state}

      :ping ->
        # send_data(state, "<iq type='get' to='#{state.host}' id='ping-#{System.unique_integer()}'><ping xmlns='urn:xmpp:ping'/></iq>")
        # Or send a whitespace ping to keep the connection alive
        send_data(state, " ")
        schedule_ping()
        {:noreply, state}

      _ ->
        Logger.debug("XmppClient UNHANDLED: #{inspect(msg)}")
        {:noreply, state}
    end
  end

  @doc "Loads all chats from the archive."
  def load_archive do
    # Using call to get a reply, but can be a cast if you don't need to wait.
    GenServer.call(__MODULE__, :load_archive)
  end

  @impl true
  def handle_call(:load_archive, _from, state) do
    query_id = "mam-" <> (:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower))

    mam_query = mam_query(id: query_id)
    mam_iq = iq(type: :set, id: query_id, sub_els: [mam_query])

    send_element(state, mam_iq)

    # Here we are just acknowledging the request was sent.
    # The results will arrive as separate messages.
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:get_new_ciphertext, password}, _from, state) do
    # GenServer is already running and presumably connected
    # Verify password matches and return a new encrypted password
    if password == state.password do
      {:reply, encrypt_password(state), state}
    else
      {:reply, {:error, :invalid_password}, state}
    end
  end

  #   def retract_message(message_id) do
  #     GenServer.call(__MODULE__, {:retract_message, message_id})
  #   end
  #
  #   @impl true
  #   def handle_call({:retract_message, message_id}, _from, state) do
  #     retract_message_id = "retract-#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}"
  #
  #     xml = """
  #       <message
  #           from='najva_test0@conversations.im/Najva'
  #           to='najva_test1@conversations.im'
  #           type='chat'
  #           id='#{retract_message_id}'>
  #         <retract xmlns='urn:xmpp:message-retract:1' id='#{message_id}'/>
  #         <body xmlns='jabber:client'>/me retracted a message.</body>
  #         <store xmlns='urn:xmpp:hints'/>
  #       </message>
  #     """
  #
  #     res = send_data(state, xml)
  #     {:reply, res, state}
  #   end

  # Step 35
  def handle_element({:xmlel, "iq", attrs, children}, state) do
    iq = :xmpp.decode({:xmlel, "iq", attrs, children})
    # Logger.info("XmppClient: received IQ: #{inspect(iq)}")
    case iq do
      # Bind result
      iq(type: :result, sub_els: [bind(jid: jid)]) ->
        schedule_ping()
        handle_bind_result(jid(jid), state)

      # Other IQ results
      iq(type: :result, id: "mam-" <> _rest) ->
        Logger.debug("XmppClient: Received an intermediate MAM IQ result.")
        {:noreply, state}

      iq() ->
        Logger.debug("XmppClient: unhandled IQ: #{inspect(iq)}")
        {:noreply, state}
    end
  end

  def handle_element({:xmlel, "message", _attrs, _children} = element, state) do
    %{"message" => message} = Fxmap.decode(element)

    new_state =
      cond do
        Map.has_key?(message, "fin") ->
          # Handle MAM query finished messages
          Logger.info("XmppClient: MAM query finished #{inspect(state.chat_map)}")
          PubSub.broadcast(Najva.PubSub, state.jid, {:mam_finished, state.chat_map})
          %{state | chat_map: %{}}

        msg_content = get_in(message, ["result", "forwarded", "message"]) ->
          # Handle forwarded/archived messages (e.g., from MAM query results)
          # Logger.info("XmppClient: received forwarded message\n#{inspect(msg_content)}\n")
          {chat_id, filtered_msg} = handle_message(state, msg_content)

          # Add the new message to the list for the correct chat_id
          %{state | chat_map: Map.put(state.chat_map, chat_id, filtered_msg)}

        Map.has_key?(message, "body") ->
          # Logger.info("XmppClient: received regular message\n#{inspect(message)}\n")
          message = handle_message(state, message)
          PubSub.broadcast(Najva.PubSub, state.jid, {:message, message})
          state

        true ->
          Logger.debug("XmppClient: unhandled message: #{inspect(message)}")
          state
      end

    {:noreply, new_state}
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
        handle_features(features, state)

      # Step 13
      {:xmlel, "proceed", _, _} ->
        # Logger.info("XmppClient: received TLS proceed, upgrading to TLS")
        handle_starttls_proceed(state)

      # Step 24
      {:xmlel, "success", _, _} ->
        # Logger.info("XmppClient: SASL success")
        handle_sasl_success(state)

      {:xmlel, "failure", _, _} ->
        Logger.error("XmppClient: SASL authentication failed")
        {:stop, :sasl_failure, state}

      _ ->
        Logger.debug("XmppClient: unhandled XML element: #{inspect(element)}")
        {:noreply, state}
    end
  end

  defp schedule_ping do
    Process.send_after(self(), :ping, @ping_interval)
  end

  defp encrypt_password(state) do
    alias Najva.XmppClient.Encryption

    case Encryption.generate_and_update_key(state.jid) do
      {:ok, key} ->
        encrypted_password = Encryption.encrypt(state.password, key)
        {:ok, encrypted_password}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def handle_message(state, message) do
    from = String.split(message["@from"], "/") |> hd()
    chat_id = if from == state.jid, do: message["@to"], else: from

    filtered_msg = %{
      from: message["@from"],
      to: message["@to"],
      text: message["body"]["@cdata"],
      time: String.to_integer(message["archived"]["@id"])
    }

    {chat_id, filtered_msg}
  end
end
