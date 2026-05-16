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
    %DirectMessage{
      owner: jid.username,
      peer: peer_jid,
      msg_id: msg_id,
      time: time
    }
    |> DirectMessage.changeset(%{
      state: :sent,
      content: content
    })
    |> Repo.insert!()

    # 2. Update chat list for sender
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
         state: :sent,
         content: content,
         time: time
       }}
    )
  end

  @doc """
  Receives parsed message from StanzaHandler and puts it into the database.
  """
  def receive_message(message) do
    %DirectMessage{
      owner: message.owner,
      peer: message.peer,
      msg_id: message.msg_id,
      time: message.time
    }
    |> DirectMessage.changeset(message)
    |> Repo.insert(on_conflict: :nothing, conflict_target: [:owner, :msg_id])

    ConversationBuffer.update_received_msg(
      message.owner,
      message.peer,
      message.content,
      message.time
    )
  end

  def list_chats(owner, before_time \\ nil) do
    ConversationBuffer.list_chats(owner, before_time)
    |> Enum.map(&enrich_conversation/1)
  end

  def get_messages(owner, peer) do
    import Ecto.Query

    from(m in DirectMessage,
      where: m.owner == ^owner and m.peer == ^peer,
      order_by: [asc: m.time]
    )
    |> Repo.all()
  end

  def enrich_conversation({:conversation, {o, p}, o2, lm, t, c, r, m} = _record) do
    {uid, host} =
      case p do
        <<id::binary-size(18)>> -> {id, nil}
        <<id::binary-size(18), "@", host::binary>> -> {id, host}
      end

    username =
      case Najva.Profiles.get_profile_by_id(uid, host) do
        {:ok, profile} -> profile.username
        _ -> p
      end

    {:conversation, {o, p}, o2, lm, t, c, r, Map.put(m, :peer_username, username)}
  end
end
