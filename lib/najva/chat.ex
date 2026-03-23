defmodule Najva.Chat do
  alias Najva.Fxmap
  alias Najva.Repo
  alias Najva.Chat.{Conversation, Message}
  alias Najva.Ejabberd

  @host %Najva{}.host

  def send_message(jid, peer, peer_host, content) do
    time = System.os_time(:millisecond)
    msg_id = "#{jid.username}_#{Integer.to_string(time, 36)}"

    filtered_host =
      case peer_host do
        @host ->
          ""

        "" ->
          ""

        _ ->
          peer_host
      end

    # 1. Insert message record for sender
    %Message{}
    |> Message.changeset(%{
      owner: jid.username,
      peer: peer,
      peer_host: filtered_host,
      msg_id: msg_id,
      state: "sending",
      content: content,
      time: time
    })
    |> Repo.insert!()

    # 2. Upsert conversation record for sender
    %Conversation{}
    |> Conversation.changeset(%{
      owner: jid.username,
      peer: peer,
      peer_host: filtered_host,
      last_msg: content,
      time: time
    })
    |> Repo.insert!(
      on_conflict: {:replace, [:last_msg, :time]},
      conflict_target: [:owner, :peer, :peer_host]
    )

    # 3. Route via ejabberd
    Ejabberd.send_message(jid, peer, peer_host, msg_id, time, content)
  end

  @doc """
  Receive a message — called by ejabberd hooks.
  1. Insert into receiver's context with state "received"
  2. Upsert/Update the local conversation record
  """
  def receive_message(from, to, n) do
    # Decoded stanza structure based on Fxmap.decode(n):
    # %{"n" => %{"content" => %{"@id" => "...", "@time" => "...", "@cdata" => "..."}}}
    stanza = Fxmap.decode(n)

    # Extract sender/recipient info from JID tuples: {:jid, user, server, res, luser, lserver, lres}
    peer = elem(from, 1)
    peer_host = elem(from, 2)
    owner = elem(to, 1)

    case stanza["n"]["content"] do
      %{"@id" => msg_id, "@time" => time_val, "@cdata" => content} ->
        # attributes from XML are strings via Fxmap
        time = String.to_integer(time_val)
        filtered_host = if peer_host == @host, do: "", else: peer_host

        # 1. Insert message record for recipient
        %Message{}
        |> Message.changeset(%{
          owner: owner,
          peer: peer,
          peer_host: filtered_host,
          msg_id: msg_id,
          state: "received",
          content: content,
          time: time
        })
        |> Repo.insert!()

        # 2. Upsert conversation record for recipient
        %Conversation{}
        |> Conversation.changeset(%{
          owner: owner,
          peer: peer,
          peer_host: filtered_host,
          last_msg: content,
          time: time
        })
        |> Repo.insert!(
          on_conflict: {:replace, [:last_msg, :time]},
          conflict_target: [:owner, :peer, :peer_host]
        )

      _ ->
        IO.warn("Najva.Chat.receive_message: Unknown stanza format: #{inspect(stanza)}")
    end
  end
end
