defmodule NajvaWeb.AppLive.Root do
  use NajvaWeb, :live_view
  alias Phoenix.PubSub

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      PubSub.subscribe(Najva.PubSub, "najva_test0@conversations.im")
      GenServer.call({:global, "najva_test0@conversations.im"}, :load_archive)
    end

    {:ok, assign(socket, chat_list: [])}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      live_action={@live_action}
      chat_list={@chat_list}
    >
      <%!-- <div class="chat-root m-1 text-white" /> --%>
    </Layouts.app>
    """
  end

  @impl true
  def handle_info({:message, new_message}, socket) do
    # IO.inspect(new_message)
    messages = [new_message | socket.assigns.chat_list]

    {:noreply, assign(socket, chat_list: messages)}
  end

  #   def handle_info({:new_message, message_payload}, socket) do
  #     # 3. Print the message (this will appear in the server logs)
  #     IO.inspect(message_payload, label: "RECEIVED MESSAGE IN LIVEVIEW")
  #
  #     # 4. Update the socket assigns to trigger a UI re-render
  #     new_messages = [message_payload | socket.assigns.messages]
  #
  #     {:noreply, assign(socket, messages: new_messages)}
  #   end
end

#     chat_list =
#       assigns.messages
#       |> Enum.group_by(
#         # Determine the conversation JID for each message.
#         fn message ->
#           # Safely get the bare JID (user@server) for both sender and receiver
#           from_jid = get_in(message, ["@attrs", "from"]) |> to_string() |> String.split("/") |> hd()
#           to_jid = get_in(message, ["@attrs", "to"]) |> to_string() |> String.split("/") |> hd()
#           my_jid = "najva_test0@conversations.im"
#
#           if from_jid == my_jid, do: to_jid, else: from_jid
#         end,
#         # For each group, create a chat summary from the most recent message.
#         fn {jid, messages} ->
#           # Sort messages within the group by timestamp to find the most recent one.
#           # The timestamp is a unix timestamp in microseconds.
#           last_message =
#             Enum.max_by(messages, fn msg ->
#               get_in(msg, ["stanza-id", "@attrs", "id"]) |> String.to_integer()
#             end)
#
#           # Extract the message body from the "@cdata" field.
#           last_message_text = get_in(last_message, ["body", "@cdata"]) || "..."
#
#           # Extract the timestamp for sorting the chat list.
#           timestamp_us =
#             get_in(last_message, ["stanza-id", "@attrs", "id"]) |> String.to_integer()
#
#           %{
#             jid: jid,
#             name: jid, # You can replace this with a real name from a contact list later
#             last_message: last_message_text,
#             # Store the raw timestamp for sorting
#             timestamp: timestamp_us
#           }
#         end
#       )
#       |> Enum.sort_by(& &1.timestamp, :desc) # This won't do much until you have real timestamps
