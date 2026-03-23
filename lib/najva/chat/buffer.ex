# defmodule Najva.Chat.Buffer do
#   @moduledoc """
#   Mnesia-backed storage for chat_list and msgs tables.
#   Uses disc_copies for durability across restarts.
#   """
#
#   require Logger
#
#   # --- Record definitions ---
#   # chat_list: {owner, peer, content, time, new_msg_count, peer_read_upto, meta}
#   # msgs:      {owner, peer, msg_id, state, content, time, meta}
#
#   @host %Najva{}.host
#
#   @doc """
#   Initialize Mnesia tables. Call once at application startup.
#   """
#   def init_tables do
#     :mnesia.create_schema([node()])
#
#     :mnesia.start()
#
#     :mnesia.create_table(:chat_list,
#       type: :bag,
#       disc_copies: [node()],
#       attributes: [
#         :owner,
#         :peer,
#         :peer_host,
#         :last_msg,
#         :time,
#         :new_msg_count,
#         :peer_read_upto,
#         :meta
#       ]
#     )
#
#     :mnesia.create_table(:message_buffer,
#       type: :bag,
#       disc_copies: [node()],
#       attributes: [
#         :owner,
#         :peer,
#         :peer_host,
#         :msg_id,
#         :state,
#         :content,
#         :time,
#         :meta
#       ]
#     )
#
#     :mnesia.wait_for_tables([:chat_list, :msgs], 5000)
#     Logger.info("[Chat.Buffer] Mnesia tables initialized")
#     :ok
#   end
#
#   # --- msgs CRUD ---
#
#   @doc """
#   Insert a message record into Mnesia.
#   """
#   def insert_msg(%{
#         owner: owner,
#         peer: peer,
#         peer_host: peer_host,
#         msg_id: msg_id,
#         state: state,
#         content: content,
#         time: time,
#         meta: meta
#       }) do
#     :mnesia.transaction(fn ->
#       :mnesia.write({:msgs, owner, peer, peer_host, msg_id, state, content, time, meta})
#     end)
#   end
#
#   @doc """
#   Update message state. Finds by owner + msg_id, updates the state field.
#   Returns :ok or :not_found.
#   """
#   def update_msg_state(owner, msg_id, new_state) do
#     :mnesia.transaction(fn ->
#       # Read all msgs for this owner
#       records = :mnesia.match_object({:msgs, owner, :_, msg_id, :_, :_, :_, :_})
#
#       case records do
#         [] ->
#           :not_found
#
#         entries ->
#           Enum.each(entries, fn {_, ^owner, peer, ^msg_id, old_state, content, time, meta} ->
#             :mnesia.delete_object({:msgs, owner, peer, msg_id, old_state, content, time, meta})
#             :mnesia.write({:msgs, owner, peer, msg_id, new_state, content, time, meta})
#           end)
#
#           :ok
#       end
#     end)
#   end
#
#   @doc """
#   Get all messages between user and peer from Mnesia.
#   """
#   def get_msgs(owner, peer) do
#     peer = normalize_peer(peer)
#
#     {:atomic, results} =
#       :mnesia.transaction(fn ->
#         :mnesia.match_object({:msgs, owner, peer, :_, :_, :_, :_, :_})
#       end)
#
#     results
#     |> Enum.map(&msg_record_to_map/1)
#     |> Enum.sort_by(& &1.time, :desc)
#   end
#
#   @doc """
#   Dump all msgs records and swap the table (atomic clear).
#   Returns the list of all records that were in the table.
#   """
#   def dump_and_swap_msgs do
#     {:atomic, records} =
#       :mnesia.transaction(fn ->
#         # Fold through entire msgs table
#         records =
#           :mnesia.foldl(
#             fn record, acc -> [record | acc] end,
#             [],
#             :msgs
#           )
#
#         # Clear the table
#         :mnesia.clear_table(:msgs)
#         records
#       end)
#
#     Enum.map(records, &msg_record_to_map/1)
#   end
#
#   # --- chat_list CRUD ---
#
#   @doc """
#   Upsert a chat_list entry. If an entry for {owner, peer} exists, it is replaced.
#   """
#   def upsert_chat_entry(%{owner: owner, peer: peer} = attrs) do
#     peer = normalize_peer(peer)
#     content = attrs |> Map.get(:content, "") |> String.slice(0, 50)
#     time = Map.get(attrs, :time, System.os_time(:millisecond))
#     new_msg_count = Map.get(attrs, :new_msg_count, 0)
#     peer_read_upto = Map.get(attrs, :peer_read_upto, %{})
#     meta = Map.get(attrs, :meta, %{})
#
#     :mnesia.transaction(fn ->
#       # Delete existing entries for this owner+peer pair
#       existing = :mnesia.match_object({:chat_list, owner, peer, :_, :_, :_, :_, :_})
#       Enum.each(existing, &:mnesia.delete_object/1)
#
#       :mnesia.write({:chat_list, owner, peer, content, time, new_msg_count, peer_read_upto, meta})
#     end)
#   end
#
#   @doc """
#   Increment the new_msg_count for an existing chat_list entry,
#   or create one if it doesn't exist.
#   """
#   def increment_chat_count(owner, peer, content, time) do
#     peer = normalize_peer(peer)
#     content = String.slice(content, 0, 50)
#
#     :mnesia.transaction(fn ->
#       existing = :mnesia.match_object({:chat_list, owner, peer, :_, :_, :_, :_, :_})
#
#       case existing do
#         [{_, ^owner, ^peer, _old_content, _old_time, count, read_upto, meta}] ->
#           Enum.each(existing, &:mnesia.delete_object/1)
#           :mnesia.write({:chat_list, owner, peer, content, time, count + 1, read_upto, meta})
#
#         _ ->
#           :mnesia.write({:chat_list, owner, peer, content, time, 1, %{}, %{}})
#       end
#     end)
#   end
#
#   @doc """
#   Get all chat_list entries for an owner.
#   """
#   def get_chat_list(owner) do
#     {:atomic, results} =
#       :mnesia.transaction(fn ->
#         :mnesia.match_object({:chat_list, owner, :_, :_, :_, :_, :_, :_})
#       end)
#
#     results
#     |> Enum.map(&chat_record_to_map/1)
#     |> Enum.sort_by(& &1.time, :desc)
#   end
#
#   @doc """
#   Get all chat_list records (for pgsql sync).
#   """
#   def all_conversations do
#     {:atomic, results} =
#       :mnesia.transaction(fn ->
#         :mnesia.foldl(fn record, acc -> [record | acc] end, [], :chat_list)
#       end)
#
#     Enum.map(results, &chat_record_to_map/1)
#   end
#
#   # --- Record ↔ Map conversions ---
#
#   defp msg_record_to_map({:msgs, owner, peer, msg_id, state, content, time, meta}) do
#     %{
#       owner: owner,
#       peer: peer,
#       msg_id: msg_id,
#       state: state,
#       content: content,
#       time: time,
#       meta: meta
#     }
#   end
#
#   defp chat_record_to_map(
#          {:chat_list, owner, peer, content, time, new_msg_count, peer_read_upto, meta}
#        ) do
#     %{
#       owner: owner,
#       peer: peer,
#       content: content,
#       time: time,
#       new_msg_count: new_msg_count,
#       peer_read_upto: peer_read_upto,
#       meta: meta
#     }
#   end
# end
