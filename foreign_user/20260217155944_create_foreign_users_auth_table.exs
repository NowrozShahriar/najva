defmodule Najva.Repo.Migrations.CreateForeignUsersAuthTable do
  use Ecto.Migration

  def change do
    create table(:foreign_users) do
      add :jid, :string
      add :encryption_key, :string
      timestamps(type: :utc_datetime)
    end

    create unique_index(:foreign_users, [:jid])
  end
end
