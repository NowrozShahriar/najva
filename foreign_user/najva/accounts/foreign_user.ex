# defmodule Najva.Accounts.ForeignUser do
#   use Ecto.Schema
#   import Ecto.Changeset
#
#   schema "foreign_users" do
#     field :jid, :string
#     field :encryption_key, :string
#
#     timestamps()
#   end
#
#   @doc false
#   def changeset(user, attrs) do
#     user
#     |> cast(attrs, [:jid, :encryption_key])
#     |> validate_required([:jid])
#     |> unique_constraint(:jid)
#   end
# end
