defmodule Najva.Chat.Conversation do
  @moduledoc """
  Ecto schema for conversations PostgreSQL table.
  Used as the durable sync target for Mnesia chat_list.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "conversations" do
    field :owner, :string, primary_key: true
    field :peer, :string, primary_key: true
    field :last_msg, :string
    field :time, :integer
    field :new_msg_count, :integer, default: 0
    field :peer_read_upto, :map, default: %{}
    field :meta, :map, default: %{}
  end

  def changeset(entry, attrs) do
    entry
    |> cast(
      attrs,
      [:owner, :peer, :last_msg, :time, :new_msg_count, :peer_read_upto, :meta]
    )
    |> validate_required([:owner, :peer, :time])
  end
end
