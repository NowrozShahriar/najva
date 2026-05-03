defmodule Najva.Profiles do
  @moduledoc """
  The Profiles context.
  Handles coordination between PostgreSQL (Repo) and Mnesia (ProfileBuffer).
  """

  alias Ecto.Multi
  alias Najva.Repo
  alias Najva.Profiles.{Profile, ProfileBuffer}

  @doc """
  Upserts a profile in Postgres and syncs the result to Mnesia using Ecto.Multi.
  """
  def put(%Profile{} = profile, attrs) do
    Multi.new()
    |> Multi.insert_or_update(:profile, Profile.changeset(profile, attrs))
    |> Multi.run(:mnesia_sync, fn _repo, %{profile: profile} ->
      ProfileBuffer.write_to_mnesia(profile)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{profile: profile}} -> {:ok, profile}
      {:error, :profile, changeset, _} -> {:error, changeset}
      {:error, step, reason, _} -> {:error, {step, reason}}
    end
  end

  @doc """
  Gets a profile.
  Tries Mnesia first for speed, falls back to Repo if not found.
  """
  def get_profile(id) do
    case ProfileBuffer.get_by_id(id) do
      {:ok, record} ->
        # Convert Mnesia record back to struct if needed,
        # or just return the data. For now, returning struct is better.
        {:ok, record_to_struct(record)}

      {:error, :not_found} ->
        case Repo.get(Profile, id) do
          nil ->
            {:error, :not_found}

          profile ->
            sync_to_cache(profile)
            {:ok, profile}
        end
    end
  end

  @doc """
  Directly syncs a profile from Postgres to Mnesia.
  Useful for initialization or recovery.
  """
  def sync_to_cache(%Profile{} = profile) do
    ProfileBuffer.write_to_mnesia(profile)
  end

  defp record_to_struct(
         {:profile, id, username, status, display_name, bio, avatar, cover, region, meta}
       ) do
    %Profile{
      id: id,
      username: username,
      status: status,
      display_name: display_name,
      bio: bio,
      avatar_url: avatar,
      cover_url: cover,
      region: region,
      meta: meta
    }
  end
end
