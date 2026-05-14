defmodule Najva.Profiles.PresenceBuffer do
  @moduledoc """
  A Mnesia wrapper for tracking user online status and last seen timestamps.
  """

  @table :presence
  @fields [:id, :is_online, :last_seen]

  @doc "Initialize the Presence table in Mnesia (RAM only, Idempotent)"
  def init_table do
    case :mnesia.create_table(@table,
           attributes: @fields,
           ram_copies: [node()]
         ) do
      {:atomic, :ok} -> :ok
      {:aborted, {:already_exists, @table}} -> :ok
      error -> error
    end
  end

  @doc """
  Updates the presence of a user.
  Uses Unix timestamp (seconds) for browser-friendly consumption.
  """
  def set_presence(id, is_online) do
    last_seen = System.system_time(:second)
    record = {@table, id, is_online, last_seen}

    case :mnesia.dirty_write(record) do
      :ok -> {:ok, record}
    end
  end

  @doc "Fetches the presence record for a user"
  def get_presence(id) do
    case :mnesia.dirty_read(@table, id) do
      [record] -> {:ok, record}
      [] -> {:error, :not_found}
    end
  end

  @doc "Deletes a presence record"
  def delete_presence(id) do
    :mnesia.dirty_delete(@table, id)
  end
end
