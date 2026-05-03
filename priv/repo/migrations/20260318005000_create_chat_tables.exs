defmodule Najva.Repo.Migrations.CreateChatTables do
  use Ecto.Migration

  def change do
    create table(:direct_messages, primary_key: false) do
      add :owner,
          references(:local_users, type: :string, on_delete: :delete_all),
          primary_key: true,
          null: false

      add :peer, :string, null: false
      add :msg_id, :string, primary_key: true, null: false
      add :state, :integer, null: false
      add :content, :text, null: false
      add :time, :bigint, null: false
      add :meta, :map, default: %{}
    end

    create index(:direct_messages, [:owner, :peer, :time])

    create table(:conversations, primary_key: false) do
      add :owner,
          references(:local_users, type: :string, on_delete: :delete_all),
          primary_key: true,
          null: false

      add :peer, :string, primary_key: true, null: false
      add :last_msg, :string
      add :time, :bigint, null: false
      add :new_msg_count, :integer, default: 0
      add :peer_read_upto, :map, default: %{}
      add :meta, :map, default: %{}
    end
  end
end
