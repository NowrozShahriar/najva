# defmodule Najva.Auth do
#   alias Najva.XmppClient.Encryption
#   alias Phoenix.PubSub
#   require Logger
#
#   # PATH A: With Cookies (restoring session using ciphertext)
#   def restore_session(jid, ciphertext) do
#     # Try to verify with existing GenServer first
#     case GenServer.call(Najva.HordeRegistry.via_tuple(jid), {:verify_session, ciphertext}) do
#       :ok ->
#         :ok
#
#       {:error, reason} ->
#         Logger.error("Failed to verify session: #{inspect(reason)}")
#         {:error, reason}
#     end
#   catch
#     :exit, {:noproc, _} ->
#       # GenServer not running, start a new client
#       start_new_session(jid, ciphertext)
#   end
#
#   defp start_new_session(jid, ciphertext) do
#     case Encryption.get_encryption_key(jid) do
#       nil ->
#         {:error, :user_not_found}
#
#       key ->
#         case Encryption.decrypt(key, ciphertext) do
#           {:ok, password} ->
#             PubSub.subscribe(Najva.PubSub, jid)
#             Najva.HordeSupervisor.start_client(jid, password, device_id: [ciphertext])
#
#             receive do
#               :authenticated ->
#                 PubSub.unsubscribe(Najva.PubSub, jid)
#                 :ok
#             after
#               15_000 ->
#                 Logger.error("Session timeout")
#                 {:error, :timeout}
#             end
#
#           {:error, reason} ->
#             Logger.error("Failed to decrypt ciphertext: #{inspect(reason)}")
#             {:error, reason}
#         end
#     end
#   end
#
#   # PATH B: Without Cookies (fresh login with password)
#   def login(jid, password) do
#     # Generate a NEW unique ciphertext for this specific device.
#     case Horde.Registry.lookup(Najva.HordeRegistry, jid) do
#       [{pid, _}] ->
#         # GS is running.
#         # 1. Tell GenServer to provide new token if password matches.
#         GenServer.call(pid, {:get_new_ciphertext, password})
#
#       [] ->
#         # GS not running. Start fresh.
#         # Subscribe to PubSub for authentication notification
#         PubSub.subscribe(Najva.PubSub, jid)
#         Najva.HordeSupervisor.start_client(jid, password)
#
#         receive do
#           {:authenticated, new_ciphertext} ->
#             PubSub.unsubscribe(Najva.PubSub, jid)
#             {:ok, new_ciphertext}
#         after
#           15_000 ->
#             {:error, :timeout}
#         end
#     end
#   end
# end
