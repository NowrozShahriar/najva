defmodule Najva.Profiles do
  @moduledoc """
  The Profiles context.
  Handles coordination between PostgreSQL (Repo) and Mnesia (ProfileBuffer).
  """

  import Ecto.Query
  alias Ecto.Multi
  alias Najva.Repo
  alias Najva.Profiles.{Profile, ProfileBuffer}
  alias Najva.Accounts.{User, UserToken}

  @doc """
  Updates the profile region based on the most frequent location from recent tokens.
  """
  def update_region(user_id) do
    region = calculate_region(user_id)

    case Repo.get(Profile, user_id) do
      nil -> {:error, :not_found}
      profile -> put(profile, %{region: region})
    end
  end

  defp calculate_region(user_id) do
    query =
      from t in UserToken,
        where: t.user_id == ^user_id and t.inserted_at > ago(1, "month"),
        where: not is_nil(t.location),
        group_by: t.location,
        order_by: [
          # 1. Primary Sort: Most frequent first
          desc: count(t.id),
          # 2. Tie-breaker: Oldest "first seen" date first
          asc: min(t.inserted_at)
        ],
        limit: 1,
        select: t.location

    Repo.one(query) || []
  end

  @doc """
  Gets a profile.
  Tries Mnesia first for speed, falls back to Repo if not found.
  """
  def get_profile(id) do
    case ProfileBuffer.get_by_id(id) do
      {:ok, record} ->
        {:ok, record_to_struct(record)}

      {:error, :not_found} ->
        case id do
          <<_uid::binary-size(18), "@", host::binary>> when host != %Najva{}.host ->
            {:error, :not_found}

          _local_user ->
            case Repo.get(Profile, id) do
              nil ->
                case Repo.get(User, id) do
                  nil -> {:error, :user_not_found}
                  user -> generate_profile(user)
                end

              profile ->
                sync_to_cache(profile)
                {:ok, profile}
            end
        end
    end
  end

  defp generate_profile(%Najva.Accounts.User{} = user) do
    region = calculate_region(user.id)

    case put(
           %Profile{id: user.id, username: user.username},
           %{region: region}
         ) do
      {:ok, profile} -> {:ok, profile}
      {:error, _changeset} -> {:error, :profile_creation_failed}
    end
  end

  @doc """
  Upserts a profile in Postgres and syncs the result to Mnesia using Ecto.Multi.
  """
  def put(%Profile{} = profile, attrs) do
    Multi.new()
    |> Multi.insert_or_update(:profile, Profile.changeset(profile, attrs))
    |> Multi.run(:mnesia_sync, fn _repo, %{profile: profile} ->
      ProfileBuffer.add_profile(profile)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{profile: profile}} -> {:ok, profile}
      {:error, :profile, changeset, _} -> {:error, changeset}
      {:error, step, reason, _} -> {:error, {step, reason}}
    end
  end

  @doc """
  Directly syncs a profile from Postgres to Mnesia.
  Useful for initialization or recovery.
  """
  def sync_to_cache(%Profile{} = profile) do
    ProfileBuffer.add_profile(profile)
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

  @doc """
  Deletes a profile from the cache.
  """
  def delete_profile_cache(id) do
    ProfileBuffer.delete_profile(id)
  end
end
