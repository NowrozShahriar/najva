defmodule Najva.HordeSupervisor do
  use Horde.DynamicSupervisor

  def start_link(_) do
    Horde.DynamicSupervisor.start_link(
      name: __MODULE__,
      strategy: :one_for_one,
      members: :auto
    )
  end

  def init(init_arg) do
    [members: :auto]
    |> Keyword.merge(init_arg)
    |> Horde.DynamicSupervisor.init()
  end

  @doc """
  Starts the XMPP Client.
  """
  def start_client(jid, password) do
    child_spec = %{
      id: Najva.XmppClient,
      start: {Najva.XmppClient, :start_link, [[jid: jid, password: password]]},
      restart: :transient
    }

    Horde.DynamicSupervisor.start_child(__MODULE__, child_spec)
  end
end
