defmodule Najva.Chat do
  alias Najva.Repo
  alias Najva.Chat.{DirectMessage, ChatList}
  alias Najva.Ejabberd

  @doc """
  Puts outgoing messages into the database then calls the ejabberd router
  """
  def send_message(jid, peer_jid, content) do
    time = System.os_time(:millisecond)
    msg_id = "#{jid.username}_#{Integer.to_string(time, 36)}"

    # 1. Insert message record for sender
    %DirectMessage{}
    |> DirectMessage.changeset(%{
      owner: jid.username,
      peer: peer_jid,
      msg_id: msg_id,
      state: "sent",
      content: content,
      time: time
    })
    |> Repo.insert!()

    # # 2. Upsert conversation record for sender
    # %Conversation{}
    # |> Conversation.changeset(%{
    #   owner: jid.username,
    #   peer: peer_jid,
    #   last_msg: content,
    #   time: time
    # })
    # |> Repo.insert!(
    #   on_conflict: {:replace, [:last_msg, :time]},
    #   conflict_target: [:owner, :peer]
    # )

    # 3. Route via ejabberd
    Ejabberd.send_message(jid, peer_jid, msg_id, time, content)
  end

  @doc """
  Receives parsed message from StanzaHandler and puts it into the database.
  """
  def receive_message(message) do
    %DirectMessage{}
    |> DirectMessage.changeset(message)
    |> Repo.insert(on_conflict: :nothing, conflict_target: [:owner, :msg_id])

    ChatList.update_received_msg(message.owner, message.peer, message.content, message.time)
  end
end
