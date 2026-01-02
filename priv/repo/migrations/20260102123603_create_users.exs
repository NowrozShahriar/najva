defmodule Najva.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :jid, :string
      add :encryption_key, :string

      timestamps()
    end
  end
end
