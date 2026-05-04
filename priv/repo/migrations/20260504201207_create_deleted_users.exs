defmodule Najva.Repo.Migrations.CreateDeletedUsers do
  use Ecto.Migration

  def change do
    create table(:deleted_users, primary_key: false) do
      add :user_id, :string, primary_key: true
      add :username, :string, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:deleted_users, [:user_id])
  end
end
