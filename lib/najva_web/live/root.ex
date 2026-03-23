defmodule NajvaWeb.Live.Root do
  use NajvaWeb, :live_view
  import NajvaWeb.Components
  alias NajvaWeb.Pages
  alias Najva.{Chat, Ejabberd, StanzaHandler}

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
        <.list_chats chat_list={@chat_list} />
      </:listpane_content>

      <%= case @live_action do %>
        <% :profile -> %>
          <Pages.profile />
        <% :settings -> %>
          <Pages.settings />
        <% _ -> %>
          <button class="btn" phx-click="send_test_message">Send Test Message</button>
      <% end %>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    socket = assign(socket, chat_list: %{})

    if connected?(socket) do
      jid = %{
        sid: Ejabberd.make_sid(),
        username: socket.assigns.current_scope.user.id,
        res: Integer.to_string(System.os_time(), 36)
      }

      Ejabberd.open_session(jid)
      # Ejabberd.send_presence(jid)

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
  def handle_info({:route, message}, socket) do
    StanzaHandler.handle_message(message)
    {:noreply, put_flash(socket, :info, "New message received!")}
  end

  @impl true
  def terminate(_reason, socket), do: Ejabberd.close_session(socket.assigns.jid)
end
