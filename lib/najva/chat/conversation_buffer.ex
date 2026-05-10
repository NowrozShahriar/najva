defmodule Najva.Chat.ConversationBuffer do
  @moduledoc """
  A simple Mnesia wrapper for the conversation list.
  """

  # The schema definition.
  # Note: The first field (:id) is always the primary key.
  # We use a composite {owner, peer} ID for uniqueness, but duplicate 'owner' as a top-level field to enable indexing, required for fast O(1) inbox lookups.
  @fields [
    :id,
    :owner,
    :last_msg,
    :time,
    :new_msg_count,
    :peer_read_upto,
    :meta
  ]

  @doc "Initialize the Conversation table in Mnesia (Idempotent)"
  def init_table do
    case :mnesia.create_table(:conversation,
           attributes: @fields,
           disc_copies: [node()],
           index: [:owner]
         ) do
      {:atomic, :ok} -> :ok
      {:aborted, {:already_exists, :conversation}} -> :ok
      error -> error
    end
  end

  @doc """
  1. Sent Messages: Updates last_msg and time.
  Auto-creates the conversation if it doesn't exist (starts count at 0).
  """
  def update_sent_msg(owner, peer, last_msg, time) do
    id = {owner, peer}

    record =
      case :mnesia.dirty_read(:conversation, id) do
        [{:conversation, ^id, ^owner, _old_msg, _old_time, count, read_upto, meta}] ->
          {:conversation, id, owner, last_msg, time, count, read_upto, meta}

        [] ->
          {:conversation, id, owner, last_msg, time, 0, nil, %{}}
      end

    :mnesia.dirty_write(record)
    {:ok, record}
  end

  @doc """
  2. Received Messages: Updates last_msg, time, and increments count.
  Auto-creates the conversation if it doesn't exist (starts count at 1).
  """
  def update_received_msg(owner, peer, last_msg, time) do
    id = {owner, peer}

    record =
      case :mnesia.dirty_read(:conversation, id) do
        [{:conversation, ^id, ^owner, _old_msg, _old_time, count, read_upto, meta}] ->
          {:conversation, id, owner, last_msg, time, count + 1, read_upto, meta}

        [] ->
          {:conversation, id, owner, last_msg, time, 1, nil, %{}}
      end

    :mnesia.dirty_write(record)
    {:ok, record}
  end

  @doc """
  3. Chat Opened: Resets new_msg_count to 0.
  Returns an error if the chat doesn't exist (cannot open a missing chat).
  """
  def reset_new_msg_count(owner, peer) do
    id = {owner, peer}

    case :mnesia.dirty_read(:conversation, id) do
      [{:conversation, ^id, ^owner, last_msg, time, count, read_upto, meta}]
      when count > 0 ->
        record = {:conversation, id, owner, last_msg, time, 0, read_upto, meta}
        :mnesia.dirty_write(record)
        {:ok, record}

      [{:conversation, ^id, ^owner, _last_msg, _time, 0, _read_upto, _meta}] ->
        :ignore

      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  4. Peer Read Receipt: Updates the watermark.
  Returns an error if the chat doesn't exist.
  """
  def update_peer_read_upto(owner, peer, read_upto_id) do
    id = {owner, peer}

    case :mnesia.dirty_read(:conversation, id) do
      [{:conversation, ^id, ^owner, last_msg, time, count, _old_read, meta}] ->
        record = {:conversation, id, owner, last_msg, time, count, read_upto_id, meta}
        :mnesia.dirty_write(record)
        {:ok, record}

      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  5. List chats for a given owner.
  Optional `before_time` allows pagination (returns chats where time < before_time).
  Sorting is expected to be handled by the frontend.
  """

  ## this is temporary, the idea is we will let the chat_list in mnesia grow then during the daily postgres backup we keep only the 50 most recent chats in mnesia, so when user want to load more we pull them from postgres.
  def list_chats(owner, before_time \\ nil) do
    :mnesia.dirty_index_read(:conversation, owner, :owner)
    |> Enum.filter(fn {:conversation, _, _, _, time, _, _, _} ->
      is_nil(before_time) or time < before_time
    end)
    |> Enum.sort_by(fn {:conversation, _, _, _, time, _, _, _} -> time end, :desc)
  end

  def get_conversation(owner, peer) do
    id = {owner, peer}

    case :mnesia.dirty_read(:conversation, id) do
      [record] -> {:ok, record}
      [] -> {:error, :not_found}
    end
  end
end

# :mnesia.dirty_match_object({:conversation, :_, :_, :_, :_, :_, :_, :_})
