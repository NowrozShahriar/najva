defmodule Najva.Chat.DirectMessage do
  @moduledoc """
  Ecto schema for direct_messages PostgreSQL table.
  Used as the durable sync target for Mnesia msgs.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "direct_messages" do
    field :owner, :string, primary_key: true
    field :peer, :string
    field :msg_id, :string, primary_key: true

    field :state, Ecto.Enum,
      values: [sent: 0, delivered: 1, received: 2, failed: 3, edited: 4, retracted: 5, deleted: 6]

    field :content, :string
    field :time, :integer
    field :meta, :map, default: %{}
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:owner, :peer, :msg_id, :state, :content, :time, :meta])
    |> validate_required([:owner, :peer, :msg_id, :state, :content, :time])
  end
end
