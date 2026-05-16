defmodule Najva.Profiles.ProfileBuffer do
  @moduledoc """
  A Mnesia wrapper for the profile table to enable fast lookups.
  """

  @fields [
    :id,
    :username,
    :status,
    :display_name,
    :bio,
    :avatar_url,
    :cover_url,
    :region,
    :meta
  ]

  @doc "Initialize the Profile table in Mnesia (Idempotent)"
  def init_table do
    # Create table with disc copies for persistence
    # We add an index on `:username` so we can do fast exact lookups by username as well.
    case :mnesia.create_table(:profile,
           attributes: @fields,
           disc_copies: [node()],
           index: [:username]
         ) do
      {:atomic, :ok} -> :ok
      {:aborted, {:already_exists, :profile}} -> :ok
      error -> error
    end
  end

  @doc """
  Syncs a profile from Postgres to Mnesia.
  Used for initial population and recovery.
  """
  def sync_profile(%Najva.Profiles.Profile{} = profile, host \\ nil) do
    record = {
      :profile,
      {profile.id, host},
      profile.username,
      profile.status,
      profile.display_name,
      profile.bio,
      profile.avatar_url,
      profile.cover_url,
      profile.region,
      profile.meta || %{}
    }

    case :mnesia.dirty_write(record) do
      :ok -> {:ok, record}
    end
  end

  def get_by_id(id, host \\ nil) do
    case :mnesia.dirty_read(:profile, {id, host}) do
      [record] -> {:ok, record}
      [] -> {:error, :not_found}
    end
  end

  @doc "Fast exact lookup by username using the secondary index"
  def get_by_username(username) do
    case :mnesia.dirty_index_read(:profile, username, :username) do
      [record | _] -> {:ok, record}
      [] -> {:error, :not_found}
    end
  end

  @doc "Deletes a profile record from Mnesia"
  def delete_profile(id, host \\ nil) do
    :mnesia.dirty_delete(:profile, {id, host})
  end
end
