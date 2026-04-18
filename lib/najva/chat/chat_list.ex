defmodule Najva.Chat.ChatList do
  @moduledoc """
  A simple Mnesia wrapper for the conversation list.
  """

  # The schema definition.
  # Note: The first field (:id) is always the primary key.
  # We use a composite {owner, peer} ID for uniqueness, but duplicate 'owner' as a top-level field to enable indexing, required for fast O(1) inbox lookups.
  @fields [
    :id,
    :owner,
    :peer,
    :last_msg,
    :time,
    :new_msg_count,
    :peer_read_upto,
    :meta
  ]

  @doc "Initialize Mnesia and Create the Table (Idempotent)"
  def init do
    # 1. Create schema directory on disk (ignored if already exists)
    :mnesia.create_schema([node()])

    # 2. Start Mnesia (ignored if already started)
    :mnesia.start()

    # 3. Create table with disc copies for persistence
    case :mnesia.create_table(:conversation,
           attributes: @fields,
           disc_copies: [node()],
           index: [:owner]
         ) do
      {:atomic, :ok} -> :ok
      {:aborted, {:already_exists, :conversation}} -> :ok
      error -> error
    end

    # 4. Wait for the table to be loaded from disk/memory before proceeding
    :mnesia.wait_for_tables([:conversation], 5000)
  end

  @doc """
  1. Sent Messages: Updates last_msg and time.
  Auto-creates the conversation if it doesn't exist (starts count at 0).
  """
  def update_sent_msg(owner, peer, last_msg, time) do
    id = {owner, peer}

    record =
      case :mnesia.dirty_read(:conversation, id) do
        [{:conversation, ^id, ^owner, ^peer, _old_msg, _old_time, count, read_upto, meta}] ->
          {:conversation, id, owner, peer, last_msg, time, count, read_upto, meta}

        [] ->
          {:conversation, id, owner, peer, last_msg, time, 0, nil, %{}}
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
        [{:conversation, ^id, ^owner, ^peer, _old_msg, _old_time, count, read_upto, meta}] ->
          {:conversation, id, owner, peer, last_msg, time, count + 1, read_upto, meta}

        [] ->
          {:conversation, id, owner, peer, last_msg, time, 1, nil, %{}}
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
      [{:conversation, ^id, ^owner, ^peer, last_msg, time, _old_count, read_upto, meta}] ->
        record = {:conversation, id, owner, peer, last_msg, time, 0, read_upto, meta}
        :mnesia.dirty_write(record)
        {:ok, record}

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
      [{:conversation, ^id, ^owner, ^peer, last_msg, time, count, _old_read, meta}] ->
        record = {:conversation, id, owner, peer, last_msg, time, count, read_upto_id, meta}
        :mnesia.dirty_write(record)
        {:ok, record}

      [] ->
        {:error, :not_found}
    end
  end
end
