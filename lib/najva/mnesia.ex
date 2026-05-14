defmodule Najva.Mnesia do
  @moduledoc """
  Centralized Mnesia initialization logic for the application.
  """

  @doc """
  Initializes Mnesia schema, starts the service, and ensures all tables are created.
  This is intended to be called during application startup.
  """
  def init do
    # 1. Create schema directory on disk (idempotent)
    :mnesia.create_schema([node()])

    # 2. Start Mnesia (idempotent)
    :mnesia.start()

    # 3. Initialize individual tables
    # Each buffer's init_table/0 should handle table creation if missing.
    Najva.Chat.ConversationBuffer.init_table()
    Najva.Profiles.ProfileBuffer.init_table()
    Najva.Profiles.PresenceBuffer.init_table()

    # 4. Wait for all critical tables to be loaded from disk/memory
    case :mnesia.wait_for_tables([:conversation, :profile, :presence], 5000) do
      :ok -> :ok
      {:timeout, tables} -> {:error, {:timeout, tables}}
      {:error, reason} -> {:error, reason}
    end
  end
end
