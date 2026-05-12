defmodule Najva.Repo.Migrations.ChangeProfileRegionToArray do
  @moduledoc """
  Migration to change the region field from a simple string to an array of strings.
  This allows storing the full location hierarchy (e.g., [country, city]) directly in the profile.
  """
  use Ecto.Migration

  def up do
    execute "ALTER TABLE profiles ALTER COLUMN region TYPE varchar[] USING ARRAY[region]"

    alter table(:profiles) do
      modify :region, {:array, :string}, null: false, default: []
    end
  end

  def down do
    execute "ALTER TABLE profiles ALTER COLUMN region TYPE varchar USING region[1]"

    alter table(:profiles) do
      modify :region, :string, null: false
    end
  end
end
