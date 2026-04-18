defmodule Najva.Chat do
  alias Najva.Repo
  alias Najva.Chat.{DirectMessage, ConversationBuffer}
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

    ConversationBuffer.update_sent_msg(jid.username, peer_jid, content, time)

    # 3. Route via ejabberd
    Ejabberd.send_message(jid, peer_jid, msg_id, time, content)

    # 4. Carbon copy: broadcast to sender's own topic
    Phoenix.PubSub.broadcast(
      Najva.PubSub,
      "user_session:#{jid.username}",
      {:message,
       %{
         owner: jid.username,
         peer: peer_jid,
         msg_id: msg_id,
         state: "sent",
         content: content,
         time: time
       }}
    )
  end

  @doc """
  Receives parsed message from StanzaHandler and puts it into the database.
  """
  def receive_message(message) do
    %DirectMessage{}
    |> DirectMessage.changeset(message)
    |> Repo.insert(on_conflict: :nothing, conflict_target: [:owner, :msg_id])

    ConversationBuffer.update_received_msg(
      message.owner,
      message.peer,
      message.content,
      message.time
    )
  end
end
