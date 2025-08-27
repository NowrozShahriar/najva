defmodule Najva.XmppClient do
    @moduledoc "Minimal XMPP client used for testing that persists and broadcasts messages."

    use GenServer
    require Logger

    @xmpp_include_path "deps/xmpp/include/xmpp.hrl"
    @record_opts [includes: [@xmpp_include_path]]

    require Record
    Record.defrecordp(:jid, Record.extract(:jid, from: @xmpp_include_path))

    Record.defrecordp(
        :stream_features,
        Record.extract(:stream_features, [from: @xmpp_include_path] ++ @record_opts)
    )

    Record.defrecordp(
        :starttls,
        Record.extract(:starttls, [from: @xmpp_include_path] ++ @record_opts)
    )

    Record.defrecordp(
        :starttls_proceed,
        Record.extract(:starttls_proceed, [from: @xmpp_include_path] ++ @record_opts)
    )

    Record.defrecordp(
        :sasl_failure,
        Record.extract(:sasl_failure, [from: @xmpp_include_path] ++ @record_opts)
    )

    Record.defrecordp(
        :sasl_success,
        Record.extract(:sasl_success, [from: @xmpp_include_path] ++ @record_opts)
    )

    Record.defrecordp(
        :sasl_mechanisms,
        Record.extract(:sasl_mechanisms, [from: @xmpp_include_path] ++ @record_opts)
    )

    Record.defrecordp(
        :sasl_auth,
        Record.extract(:sasl_auth, [from: @xmpp_include_path] ++ @record_opts)
    )

    Record.defrecordp(:iq, Record.extract(:iq, [from: @xmpp_include_path] ++ @record_opts))
    Record.defrecordp(:bind, Record.extract(:bind, [from: @xmpp_include_path] ++ @record_opts))

    Record.defrecordp(
        :presence,
        Record.extract(:presence, [from: @xmpp_include_path] ++ @record_opts)
    )

    Record.defrecordp(
        :message,
        Record.extract(:message, [from: @xmpp_include_path] ++ @record_opts)
    )

    @doc "Start the XMPP client. Options: :jid, :password, :host, :port"
    def start_link(opts) when is_list(opts) do
        GenServer.start_link(__MODULE__, opts, name: __MODULE__)
    end

    @impl true
    def init(opts) do
        jid_str = opts[:jid] || "najva_test0@xmpp.social"
        password = opts[:password] || "12345678"
        host = opts[:host] || "xmpp.social"
        port = opts[:port] || 5222

        jid = "#{jid_str}/Najva-#{System.os_time(:millisecond)}"

        state = %{
            jid: jid,
            password: password,
            host: host,
            port: port,
            connection_state: :connecting,
            stream_state: :fxml_stream.new(self(), host, []),
            socket: nil
        }

        Logger.info("Najva.XmppClient: connecting to #{host}:#{port}")
        send(self(), :connect)
        {:ok, state}
    end

    @impl true
    def handle_info(:connect, state) do
        host = to_charlist(state.host)
        socket_opts = [:binary, packet: :raw, active: :once, keepalive: true]

        case :gen_tcp.connect(host, state.port, socket_opts) do
            {:ok, sock} ->
                Logger.info("Najva.XmppClient: tcp connected")
                new_state = %{state | socket: sock}
                send_stream_header(new_state)
                {:noreply, new_state}

            {:error, reason} ->
                Logger.error("Najva.XmppClient: connect error #{inspect(reason)}")
                {:stop, {:tcp_connect_failed, reason}, state}
        end
    end

    #
    # 	 def handle_info({:tcp, socket, data}, %{socket: socket} = state), do: parse_and_continue(state, data, :tcp)
    # 	 def handle_info({:ssl, socket, data}, %{socket: socket} = state), do: parse_and_continue(state, data, :ssl)
    #
    # 	 def handle_info({:tcp_closed, socket}, %{socket: socket} = state) do
    # 	 Logger.warning("Najva.XmppClient: tcp closed")
    # 		 {:stop, :normal, state}
    # 	 end
    #
    # 	 def handle_info({:ssl_closed, socket}, %{socket: socket} = state) do
    # 	 Logger.warning("Najva.XmppClient: ssl closed")
    # 		 {:stop, :normal, state}
    # 	 end
    #
    # 	 def handle_info({:xmlstreamelement, element}, state), do: handle_element(element, state)
    # 	 def handle_info(msg, state) do
    # 		 Logger.debug("Najva.XmppClient unhandled: #{inspect(msg)}")
    # 		 {:noreply, state}
    # 	 end
    #
    # 	 defp parse_and_continue(state, data, transport) do
    # 		 new_stream_state = :fxml_stream.parse(state.stream_state, data)
    #
    # 		 case transport do
    # 			 :ssl -> :ssl.setopts(state.socket, active: :once)
    # 			 :tcp -> :inet.setopts(state.socket, active: :once)
    # 		 end
    #
    # 		 {:noreply, %{state | stream_state: new_stream_state}}
    # 	 end
    #
    defp send_data(%{connection_state: :tls_upgraded, socket: sock}, data),
        do: :ssl.send(sock, data)

    defp send_data(%{socket: sock}, data), do: :gen_tcp.send(sock, data)
    #
    # 	 defp send_element(state, element) do
    # 		 xml = :xmpp.encode(element)
    # 		 bin = :fxml.element_to_binary(xml)
    # 		 send_data(state, bin)
    # 	 end
    #
    defp send_stream_header(state) do
        header =
            "<stream:stream to='" <>
                to_string(state.host) <>
                "' xmlns='jabber:client' xmlns:stream='http://etherx.jabber.org/streams' version='1.0'>"

        send_data(state, header)
    end

    #
    # 	 defp handle_element(element, state) do
    # 		 case element do
    # 			 stream_features(sub_els: features) ->
    # 				 cond do
    # 					 Enum.any?(features, &match?(starttls(), &1)) ->
    # 						 Logger.info("Najva.XmppClient: server supports STARTTLS")
    # 						 send_element(state, starttls())
    # 						 {:noreply, %{state | connection_state: :starttls_sent}}
    #
    # 					 :xmpp.get_subtag(element, :mechanisms) != nil ->
    # 						 do_sasl_auth(state, element)
    #
    # 					 :xmpp.get_subtag(element, :bind) != nil ->
    # 						 # Server advertises bind feature, request resource bind
    # 						 do_bind(state)
    #
    # 					 true ->
    # 						 {:noreply, state}
    # 				 end
    #
    # 			 element when state.connection_state == :starttls_sent ->
    # 				 case element do
    # 					 starttls_proceed() ->
    # 						 Logger.info("Najva.XmppClient: STARTTLS proceed received, upgrading to TLS (test: verify_none)")
    # 						 case :ssl.connect(state.socket, [{:active, :once}, {:verify, :verify_none}], 5_000) do
    # 							 {:ok, tls_sock} ->
    # 								 new_state = %{state | socket: tls_sock, connection_state: :tls_upgraded, stream_state: :fxml_stream.new(self(), to_charlist(state.host), [])}
    # 								 send_stream_header(new_state)
    # 								 {:noreply, new_state}
    #
    # 							 {:error, reason} ->
    # 								 Logger.error("Najva.XmppClient: TLS upgrade failed #{inspect(reason)}")
    # 								 {:stop, {:tls_failed, reason}, state}
    # 						 end
    #
    # 					 other ->
    # 						 Logger.warning("Najva.XmppClient: unexpected while waiting starttls: #{inspect(other)}")
    # 						 {:noreply, state}
    # 				 end
    #
    # 			 sasl_success() ->
    # 				 Logger.info("Najva.XmppClient: SASL success")
    # 				 new_state = %{state | stream_state: :fxml_stream.new(self(), to_charlist(state.host), [])}
    # 				 send_stream_header(new_state)
    # 				 {:noreply, new_state}
    #
    # 			 sasl_failure() ->
    # 				 Logger.error("Najva.XmppClient: SASL failure")
    # 				 {:stop, :auth_failed, state}
    #
    # 			 iq(type: :result, sub_els: sub_els) ->
    # 				 case Enum.find(sub_els, &match?(bind(), &1)) do
    # 					 bind(jid: full_jid) when full_jid != :undefined ->
    # 						 jid_string = :jid.to_string(full_jid) |> to_string()
    # 						 Logger.info("Najva.XmppClient: bound as #{jid_string}")
    # 						 send_initial_presence(state)
    # 						 {:noreply, %{state | connection_state: :session_started}}
    #
    # 					 _ ->
    # 						 {:noreply, state}
    # 				 end
    #
    # 			 message(from: from, sub_els: sub_els) when from != :undefined ->
    # 				 from_jid = :jid.to_string(from) |> to_string()
    # 				 body = :xmpp.get_text(sub_els) |> to_string()
    #
    # 				 msg = %{
    # 					 id: :crypto.strong_rand_bytes(8) |> Base.encode16(),
    # 					 from: from_jid,
    # 					 body: body,
    # 					 timestamp: DateTime.utc_now()
    # 				 }
    #
    # 				 Task.start(fn ->
    # 					 try do
    # 						 Najva.MessageStore.add_message(msg)
    # 					 rescue
    # 						 e -> Logger.error("Najva.MessageStore.add_message failed: #{inspect(e)}")
    # 					 end
    #
    # 					 Phoenix.PubSub.broadcast(Najva.PubSub, "messages:all", {:new_message, msg})
    # 				 end)
    #
    # 				 {:noreply, state}
    #
    # 			 presence() ->
    # 				 {:noreply, state}
    #
    # 			 other ->
    # 				 Logger.debug("Najva.XmppClient: unhandled element #{inspect(other)}")
    # 				 {:noreply, state}
    # 		 end
    # 	 end
    #
    # 	 defp do_sasl_auth(state, stream_features_element) do
    # 		 case :xmpp.get_subtag(stream_features_element, :mechanisms) do
    # 			 sasl_mechanisms(list: mechanisms) when is_list(mechanisms) ->
    # 				 mech_strings = Enum.map(mechanisms, &to_string/1)
    #
    # 				 if Enum.member?(mech_strings, "PLAIN") do
    # 					 jid_str = :jid.to_string(state.jid) |> to_string()
    # 					 username = jid_str |> String.split("@") |> List.first()
    # 					 auth_str = <<0, username::binary, 0, state.password::binary>>
    # 					 auth_data = Base.encode64(auth_str)
    # 					 auth_el = sasl_auth(mechanism: "PLAIN", text: auth_data)
    # 					 send_element(state, auth_el)
    # 					 {:noreply, state}
    # 				 else
    # 					 Logger.error("Najva.XmppClient: server does not support PLAIN: #{inspect(mech_strings)}")
    # 					 {:stop, :no_plain, state}
    # 				 end
    #
    # 			 _ ->
    # 				 Logger.error("Najva.XmppClient: no SASL mechanisms")
    # 				 {:stop, :no_sasl, state}
    # 		 end
    # 	 end
    #
    # 	 defp do_bind(state) do
    # 		 bind_el = bind()
    # 		 iq_id = :crypto.strong_rand_bytes(8) |> Base.encode16()
    # 		 iq_el = iq(type: :set, id: iq_id, sub_els: [bind_el])
    # 		 send_element(state, iq_el)
    # 		 {:noreply, state}
    # 	 end
    #
    # 	 defp send_initial_presence(state) do
    # 		 presence_el = presence()
    # 		 send_element(state, presence_el)
    # 	 end
end
