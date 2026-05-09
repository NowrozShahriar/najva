# defmodule Najva.Profiles do
#   @moduledoc """
#   The Profiles context.
#   Handles coordination between PostgreSQL (Repo) and Mnesia (ProfileBuffer).
#   """
#
#   alias Ecto.Multi
#   alias Najva.Repo
#   alias Najva.Profiles.{Profile, ProfileBuffer}
#
#   @doc """
#   Upserts a profile in Postgres and syncs the result to Mnesia using Ecto.Multi.
#   """
#   def put(%Profile{} = profile, attrs) do
#     Multi.new()
#     |> Multi.insert_or_update(:profile, Profile.changeset(profile, attrs))
#     |> Multi.run(:mnesia_sync, fn _repo, %{profile: profile} ->
#       ProfileBuffer.add_profile(profile)
#     end)
#     |> Repo.transaction()
#     |> case do
#       {:ok, %{profile: profile}} -> {:ok, profile}
#       {:error, :profile, changeset, _} -> {:error, changeset}
#       {:error, step, reason, _} -> {:error, {step, reason}}
#     end
#   end
#
#   @doc """
#   Gets a profile.
#   Tries Mnesia first for speed, falls back to Repo if not found.
#   If the profile doesn't exist in Repo, it creates one lazily.
#   """
#   def get_profile(id, ip \\ nil) do
#     case ProfileBuffer.get_by_id(id) do
#       {:ok, record} ->
#         {:ok, record_to_struct(record)}
#
#       {:error, :not_found} ->
#         case id do
#           <<_uid::binary-size(18), "@", host::binary>> when host != %Najva{}.host ->
#             {:error, :not_found}
#
#           _local_user ->
#             case Repo.get(Profile, id) do
#               nil ->
#                 # Lazy Create
#                 case Repo.get(Najva.Accounts.User, id) do
#                   nil ->
#                     {:error, :user_not_found}
#
#                   user ->
#                     region = "Unknown"
#
#                     profile_attrs = %{
#                       id: id,
#                       username: user.username,
#                       region: region,
#                       status: :active
#                     }
#
#                     case put(%Profile{}, profile_attrs) do
#                       {:ok, profile} -> {:ok, profile}
#                       {:error, _changeset} -> {:error, :profile_creation_failed}
#                     end
#                 end
#
#               profile ->
#                 sync_to_cache(profile)
#                 {:ok, profile}
#             end
#         end
#     end
#   end
#
#   @doc """
#   Directly syncs a profile from Postgres to Mnesia.
#   Useful for initialization or recovery.
#   """
#   def sync_to_cache(%Profile{} = profile) do
#     ProfileBuffer.add_profile(profile)
#   end
#
#   defp record_to_struct(
#          {:profile, id, username, status, display_name, bio, avatar, cover, region, meta}
#        ) do
#     %Profile{
#       id: id,
#       username: username,
#       status: status,
#       display_name: display_name,
#       bio: bio,
#       avatar_url: avatar,
#       cover_url: cover,
#       region: region,
#       meta: meta
#     }
#   end
#
#   @doc """
#   Deletes a profile from the cache.
#   """
#   def delete_profile_cache(id) do
#     ProfileBuffer.delete_profile(id)
#   end
# end
