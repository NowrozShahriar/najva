# defmodule Najva.HordeRegistry do
#   use Horde.Registry
#
#   def start_link(_) do
#     Horde.Registry.start_link(keys: :unique, name: __MODULE__, members: :auto)
#   end
#
#   def init(init_arg) do
#     [members: :auto]
#     |> Keyword.merge(init_arg)
#     |> Horde.Registry.init()
#   end
#
#   @doc """
#   Helper to generate the via tuple for addressing processes.
#   Usage: via_tuple("user@xmpp.server")
#   """
#   def via_tuple(jid) do
#     {:via, Horde.Registry, {__MODULE__, jid}}
#   end
# end
