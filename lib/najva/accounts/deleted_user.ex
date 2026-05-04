defmodule Najva.Accounts.DeletedUser do
  @moduledoc """
  Tracks users whose account deletion succeeded (Postgres + Ejabberd)
  but whose cache cleanup failed. A background job can retry these later.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:user_id, :string, autogenerate: false}
  @derive {Phoenix.Param, key: :user_id}
  schema "deleted_users" do
    field :username, :string

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc false
  def changeset(deleted_user, attrs) do
    deleted_user
    |> cast(attrs, [:user_id, :username])
    |> validate_required([:user_id, :username])
  end
end
