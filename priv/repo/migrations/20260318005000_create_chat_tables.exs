defmodule Najva.Repo.Migrations.CreateChatTables do
  use Ecto.Migration

  def change do
    create table(:direct_messages, primary_key: false) do
      add :owner,
          references(:local_users, type: :string, on_delete: :delete_all),
          null: false

      add :peer, :string, null: false
      add :msg_id, :string, null: false
      add :state, :string, null: false
      add :body, :text
      add :time, :bigint, null: false
      add :meta, :map, default: %{}
    end

    create unique_index(:direct_messages, [:owner, :msg_id])
    create index(:direct_messages, [:owner, :peer, :time])

    create table(:conversations, primary_key: false) do
      add :owner,
          references(:local_users, type: :string, on_delete: :delete_all),
          null: false

      add :peer, :string, null: false
      add :body, :string, size: 50
      add :time, :bigint, null: false
      add :new_msg_count, :integer, default: 0
      add :peer_read_upto, :map, default: %{}
      add :meta, :map, default: %{}
    end

    create unique_index(:conversations, [:owner, :peer])
  end
end
