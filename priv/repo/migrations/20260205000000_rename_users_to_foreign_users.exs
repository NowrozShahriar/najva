defmodule Najva.Repo.Migrations.RenameUsersToForeignUsers do
  use Ecto.Migration

  def change do
    rename table(:users), to: table(:foreign_users)
  end
end
