# defmodule Najva.Chat.Sync do
#   @moduledoc """
#   GenServer that periodically syncs Mnesia data to PostgreSQL.
#   - msgs: every 5 seconds via table-swap pattern
#   - chat_list: every 24 hours
#   - On startup: loads chat_list from pgsql into Mnesia
#   """
#   use GenServer
#   require Logger
#
#   import Ecto.Query
#   alias Najva.Repo
#   alias Najva.Chat.{Store, Message, Conversation}
#
#   @msgs_interval :timer.seconds(5)
#   @chat_list_interval :timer.hours(24)
#
#   def start_link(_opts) do
#     GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
#   end
#
#   @impl true
#   def init(:ok) do
#     # Load chat_list from pgsql into Mnesia on startup
#     load_chat_list_from_pg()
#
#     # Schedule periodic syncs
#     Process.send_after(self(), :sync_msgs, @msgs_interval)
#     Process.send_after(self(), :sync_chat_list, @chat_list_interval)
#
#     Logger.info("[Chat.Sync] Started — msgs every 5s, chat_list every 24h")
#     {:ok, %{}}
#   end
#
#   @impl true
#   def handle_info(:sync_msgs, state) do
#     sync_msgs_to_pg()
#     Process.send_after(self(), :sync_msgs, @msgs_interval)
#     {:noreply, state}
#   end
#
#   @impl true
#   def handle_info(:sync_chat_list, state) do
#     sync_chat_list_to_pg()
#     Process.send_after(self(), :sync_chat_list, @chat_list_interval)
#     {:noreply, state}
#   end
#
#   # --- Msgs sync (table-swap) ---
#
#   defp sync_msgs_to_pg do
#     records = Store.dump_and_swap_msgs()
#
#     if records != [] do
#       entries =
#         Enum.map(records, fn msg ->
#           %{
#             owner: msg.owner,
#             peer: msg.peer,
#             msg_id: msg.msg_id,
#             state: msg.state,
#             content: msg.content,
#             time: msg.time,
#             meta: msg.meta
#           }
#         end)
#
#       Repo.insert_all(Message, entries,
#         on_conflict: {:replace, [:state, :content, :meta]},
#         conflict_target: [:owner, :msg_id]
#       )
#
#       Logger.debug("[Chat.Sync] Synced #{length(entries)} msgs to pgsql")
#     end
#   end
#
#   # --- Chat list sync ---
#
#   defp sync_chat_list_to_pg do
#     records = Store.all_conversations()
#
#     if records != [] do
#       entries =
#         Enum.map(records, fn entry ->
#           %{
#             owner: entry.owner,
#             peer: entry.peer,
#             content: entry.content,
#             time: entry.time,
#             new_msg_count: entry.new_msg_count,
#             peer_read_upto: entry.peer_read_upto,
#             meta: entry.meta
#           }
#         end)
#
#       Repo.insert_all(ChatEntry, entries,
#         on_conflict: {:replace, [:content, :time, :new_msg_count, :peer_read_upto, :meta]},
#         conflict_target: [:owner, :peer]
#       )
#
#       Logger.debug("[Chat.Sync] Synced #{length(entries)} chat_list entries to pgsql")
#     end
#   end
#
#   # --- Load from pgsql on startup ---
#
#   defp load_chat_list_from_pg do
#     entries = Repo.all(from(c in Conversation))
#
#     Enum.each(entries, fn entry ->
#       Store.upsert_chat_entry(%{
#         owner: entry.owner,
#         peer: entry.peer,
#         content: entry.content || "",
#         time: entry.time,
#         new_msg_count: entry.new_msg_count,
#         peer_read_upto: entry.peer_read_upto,
#         meta: entry.meta
#       })
#     end)
#
#     Logger.info("[Chat.Sync] Loaded #{length(entries)} chat_list entries from pgsql")
#   end
# end
