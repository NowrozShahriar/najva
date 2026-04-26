defmodule NajvaWeb.Live.Root do
  use NajvaWeb, :live_view
  import NajvaWeb.Components
  alias NajvaWeb.Pages
  alias Najva.Chat

  on_mount {NajvaWeb.UserAuth, :mount_current_scope}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      live_action={@live_action}
      current_scope={@current_scope}
      flash={@flash}
    >
      <:listpane_content>
        <.list_chats chat_list={@streams.chat_list} />
      </:listpane_content>

      <%= case @live_action do %>
        <% :profile -> %>
          <Pages.profile />
        <% :settings -> %>
          <Pages.settings />
        <% :chat -> %>
          <Pages.chat messages={@streams.messages} peer={@peer} />
        <% _ -> %>
          <button class="btn" phx-click="send_test_message">Send Test Message</button>
      <% end %>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_scope.user.id
    chat_list = Chat.ConversationBuffer.list_chats(user_id)

    socket =
      socket
      |> stream_configure(:chat_list,
        dom_id: fn {:conversation, {owner, peer}, _, _, _, _, _, _, _} ->
          "conv-#{owner}#{peer}"
        end
      )
      |> stream_configure(:messages, dom_id: fn %{msg_id: msg_id} -> "msg-#{msg_id}" end)
      |> stream(:chat_list, chat_list)
      |> stream(:messages, [])

    if connected?(socket) do
      jid = Najva.UserSession.get_jid(user_id)
      Phoenix.PubSub.subscribe(Najva.PubSub, "user_session:#{user_id}")

      {:ok, assign(socket, jid: jid)}
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_params(_params, url, socket) do
    {:noreply, assign(socket, current_path: url)}
  end

  @impl true
  def handle_event("send_test_message", _params, %{assigns: %{jid: jid}} = socket) do
    Chat.send_message(
      jid,
      "1jkdji0bv1p2kl4hjo",
      "Hello from Najva!"
    )

    {:noreply, socket}
  end

  @impl true
  def handle_event("select_chat", %{"peer" => peer}, socket) do
    user_id = socket.assigns.current_scope.user.id

    case Chat.ConversationBuffer.reset_new_msg_count(user_id, peer) do
      {:ok, record} ->
        {:noreply, stream_insert(socket, :chat_list, record)}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:message, message}, socket) do
    IO.inspect(message, label: "\n /root received message")

    flash_msg =
      if message.state == "received",
        do: "New message from #{message.peer}",
        else: "Message sent to #{message.peer}"

    socket =
      case Chat.ConversationBuffer.get_conversation(message.owner, message.peer) do
        {:ok, record} ->
          stream_insert(socket, :chat_list, record, at: 0)

        {:error, _} ->
          socket
      end

    {:noreply, put_flash(socket, :info, flash_msg)}
  end

  @impl true
  def handle_info(message, socket) do
    IO.inspect(message, label: "\n /root received")
    {:noreply, socket}
  end

  @impl true
  def terminate(_reason, _socket), do: :ok
end
