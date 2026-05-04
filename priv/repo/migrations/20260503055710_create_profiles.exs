defmodule Najva.Repo.Migrations.CreateProfiles do
  use Ecto.Migration

  def change do
    create table(:profiles, primary_key: false) do
      add :id,
          references(:local_users, type: :string, on_delete: :delete_all),
          primary_key: true,
          null: false

      add :username, :string, null: false
      add :status, :integer, null: false, default: 0
      add :display_name, :string
      add :bio, :text
      add :avatar_url, :string
      add :cover_url, :string
      add :region, :string, null: false
      add :meta, :map
    end

    create unique_index(:profiles, [:username])
  end
end
