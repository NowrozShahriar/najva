defmodule Najva.Repo.Migrations.CreateLocalUsersAuthTables do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""

    create table(:local_users, primary_key: false) do
      add :id, :string, primary_key: true
      add :username, :citext, null: false
      add :hashed_password, :string
      add :email, :citext
      add :confirmed_at, :utc_datetime

      timestamps(type: :utc_datetime, inserted_at: false)
    end

    create unique_index(:local_users, [:username])

    create table(:users_tokens) do
      add :user_id, references(:local_users, type: :string, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      add :authenticated_at, :utc_datetime

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:users_tokens, [:user_id])
    create unique_index(:users_tokens, [:context, :token])
  end
end
