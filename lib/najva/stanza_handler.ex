defmodule Najva.StanzaHandler do
  alias Najva.Fxmap
  alias Najva.Chat

  def handle_message({:message, _id, _type, _lang, from, to, _subj, _body, _thread, [n], _meta}) do
    map = Fxmap.decode(n)

    case map do
      %{"n" => %{"@type" => type}} when type in ["chat", "groupchat"] ->
        Chat.receive_message(from, to, map["n"]["content"])

      _ ->
        :ok
    end
  end
end
