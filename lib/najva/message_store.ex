defmodule Najva.MessageStore do
  @moduledoc """
  Simple message store backed by ETS for keeping recent XMPP messages.

  Provides a small API for adding messages and listing them. Messages are
  stored as tuples {id, from, body, timestamp} and kept in an ETS table.
  """
  use GenServer

  @table :najva_messages
  @max_messages 500

  # Public API
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @doc "Add a message map. Expected keys: :id, :from, :body, :timestamp"
  def add_message(%{id: id, from: from, body: body, timestamp: timestamp} = _msg) do
    :ets.insert(@table, {id, from, body, timestamp})
    # Trim if needed
    trim_table()
    :ok
  end

  @doc "List recent messages (newest first)."
  def list_messages(limit \\ 100) do
    :ets.tab2list(@table)
    |> Enum.sort_by(fn {_id, _from, _body, ts} -> ts end, :desc)
    |> Enum.take(limit)
    |> Enum.map(fn {id, from, body, ts} -> %{id: id, from: from, body: body, timestamp: ts} end)
  end

  @doc "List messages for a given JID (bare or full)."
  def list_messages_for(jid, limit \\ 100) do
    jid_str = to_string(jid)

    list_messages()
    |> Enum.filter(fn %{from: from} -> String.contains?(from, jid_str) end)
    |> Enum.take(limit)
  end

  # GenServer callbacks
  @impl true
  def init(_arg) do
    # Create ETS table to store messages. Public for direct reads if needed.
    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    {:ok, %{}}
  end

  defp trim_table do
    # Keep only latest @max_messages by timestamp
    entries = :ets.tab2list(@table)

    if length(entries) > @max_messages do
      entries
      |> Enum.sort_by(fn {_id, _from, _body, ts} -> ts end)
      |> Enum.take(length(entries) - @max_messages)
      |> Enum.each(fn {id, _from, _body, _ts} -> :ets.delete(@table, id) end)
    end
  end
end
