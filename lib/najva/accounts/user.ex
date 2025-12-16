defmodule Najva.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :jid, :string

    # We ONLY store the key. The actual XMPP password is never stored here.
    field :encryption_key, :string

    timestamps()
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:jid, :encryption_key])
    |> validate_required([:jid])
    |> unique_constraint(:jid)
  end
end
