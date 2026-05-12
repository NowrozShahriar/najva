defmodule Najva.StanzaHandler do
  alias Najva.Fxmap
  alias Najva.Chat

  @host %Najva{}.host

  def handle_message(
        {:message, _id, _type, _lang, from, to, _subj, _body, _thread, [n], _meta},
        online \\ false
      ) do
    {:jid, from_user, from_server, _, _, _, _} = from
    {:jid, to_user, _, _, _, _, _} = to

    peer = normalize_peer(from_user, from_server)
    map = Fxmap.decode(n)

    case map do
      %{"n" => %{"@type" => "chat", "content" => content}} ->
        time =
          case content["@time"] do
            nil -> System.os_time(:millisecond)
            t when is_integer(t) -> t
            t when is_binary(t) -> String.to_integer(t)
            _ -> System.os_time(:millisecond)
          end

        message = %{
          owner: to_user,
          peer: peer,
          msg_id: content["@id"],
          state: :received,
          content: content["@cdata"],
          time: time
        }

        Chat.receive_message(message)

        online && broadcast(to_user, {:message, message})

      _ ->
        :ok
    end
  end

  defp normalize_peer(user, server) do
    if server == @host do
      user
    else
      "#{user}@#{server}"
    end
  end

  defp broadcast(user_id, info) do
    Phoenix.PubSub.broadcast(Najva.PubSub, "user_session:#{user_id}", info)
  end
end
