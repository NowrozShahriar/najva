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
          <Pages.profile profile={@profile} current_scope={@current_scope} />
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
        dom_id: fn {:conversation, {owner, peer}, _, _, _, _, _, _} ->
          "conv-#{owner}#{peer}"
        end
      )
      |> stream_configure(:messages, dom_id: fn %{msg_id: msg_id} -> "msg-#{msg_id}" end)
      |> stream(:chat_list, chat_list)

    if connected?(socket) do
      jid = Najva.UserSession.get_jid(user_id)
      Phoenix.PubSub.subscribe(Najva.PubSub, "user_session:#{user_id}")

      {:ok, assign(socket, jid: jid)}
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_event(
        "send_message",
        %{"content" => content},
        %{assigns: %{jid: jid, peer: peer}} = socket
      ) do
    Chat.send_message(jid, peer, content)
    {:noreply, socket}
  end

  @impl true
  def handle_event("send_test_message", _params, %{assigns: %{jid: jid}} = socket) do
    Chat.send_message(
      jid,
      "1jkdji0bv1p2kl4hjo",
      "Saved message."
    )

    {:noreply, socket}
  end

  @impl true
  def handle_event("open_chat", %{"peer" => peer}, socket) do
    {:noreply, push_patch(socket, to: ~p"/messages/#{peer}")}
  end

  @impl true
  def handle_info({:message, message}, socket) do
    flash_msg =
      if message.state == "received",
        do: "New message from #{message.peer}",
        else: "Message sent to #{message.peer}"

    socket =
      if socket.assigns.live_action == :chat and socket.assigns.peer == message.peer do
        case Chat.ConversationBuffer.reset_new_msg_count(message.owner, message.peer) do
          {:ok, record} ->
            socket
            |> stream_insert(:chat_list, record, at: 0)
            |> stream_insert(:messages, message)

          _ ->
            stream_insert(socket, :messages, message)
        end
      else
        case Chat.ConversationBuffer.get_conversation(message.owner, message.peer) do
          {:ok, record} ->
            stream_insert(socket, :chat_list, record, at: 0)

          _ ->
            socket
        end
        |> put_flash(:info, flash_msg)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_info(info, socket) do
    IO.inspect(info, label: "\n /root received")
    {:noreply, socket}
  end

  @impl true
  def terminate(_reason, _socket), do: :ok

  defp apply_action(socket, :chat, %{"peer" => peer}) do
    user_id = socket.assigns.current_scope.user.id
    messages = Chat.get_messages(user_id, peer)

    socket =
      socket
      |> assign(peer: peer)
      |> stream(:messages, messages, reset: true)

    case Chat.ConversationBuffer.reset_new_msg_count(user_id, peer) do
      {:ok, record} -> stream_insert(socket, :chat_list, record)
      :ignore -> socket
      _ -> socket
    end
  end

  defp apply_action(socket, :profile, _params) do
    # user_id = socket.assigns.current_scope.user.id
    # {:ok, profile} = Najva.Profiles.get_profile(user_id, socket.assigns.remote_ip)

    socket
    |> assign(peer: nil, profile: nil)
    |> stream(:messages, [], reset: true)
  end

  defp apply_action(socket, _live_action, _params) do
    socket
    |> assign(peer: nil, profile: nil)
    |> stream(:messages, [], reset: true)
  end
end
