defmodule Najva.Profiles.Profile do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  @foreign_key_type :string
  schema "profiles" do
    field :username, :string
    field :status, Ecto.Enum, values: [active: 0, unpublished: 1, warning: 2], default: :active
    field :display_name, :string
    field :bio, :string
    field :avatar_url, :string
    field :cover_url, :string
    field :region, {:array, :string}
    field :meta, :map
  end

  @doc false
  def changeset(profile, attrs) do
    profile
    |> cast(attrs, [
      :status,
      :display_name,
      :bio,
      :avatar_url,
      :cover_url,
      :region,
      :meta
    ])
    |> validate_required([:id, :username, :status, :region])
    |> unique_constraint(:username)
  end
end
