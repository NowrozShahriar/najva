defmodule Najva.Chat.Message do
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
    field :peer_host, :string
    field :msg_id, :string, primary_key: true
    field :state, :string
    field :content, :string
    field :time, :integer
    field :meta, :map, default: %{}
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:owner, :peer, :peer_host, :msg_id, :state, :content, :time, :meta],
      empty_values: []
    )
    |> validate_required([:owner, :peer, :msg_id, :state, :content, :time])
  end
end
