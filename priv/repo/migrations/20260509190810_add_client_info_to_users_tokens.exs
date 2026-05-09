defmodule Najva.Repo.Migrations.AddClientInfoToUsersTokens do
  use Ecto.Migration

  def change do
    rename table(:users_tokens), :sent_to, to: :ip

    alter table(:users_tokens) do
      add :sent_to, :string
      add :browser, :string
      add :os, :string
      add :iso, :string
      add :location, {:array, :string}
      add :isp, :string
      add :user_agent, :string
    end
  end
end
