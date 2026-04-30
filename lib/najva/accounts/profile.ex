defmodule Najva.Accounts.Profile do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  @foreign_key_type :string
  schema "profiles" do
    field :username, :string
    field :status, Ecto.Enum, values: [:active, :unpublished, :warning], default: :active
    field :display_name, :string
    field :bio, :string
    field :avatar_url, :string
    field :cover_url, :string
    field :region, :string
    field :meta, :map

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(profile, attrs) do
    profile
    |> cast(attrs, [
      :id,
      :username,
      :status,
      :display_name,
      :bio,
      :avatar_url,
      :cover_url,
      :region,
      :meta
    ])
    |> validate_required([:id, :username, :status])
    |> unique_constraint(:username)
  end
end
