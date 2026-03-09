defmodule NajvaWeb.Live.Root do
  use NajvaWeb, :live_view
  alias Najva.Ejabberd
  alias NajvaWeb.Pages

  on_mount {NajvaWeb.UserAuth, :mount_current_scope}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      live_action={@live_action}
      current_scope={@current_scope}
    >
      <Pages.profile :if={@live_action == :profile} />
      <Pages.settings :if={@live_action == :settings} />
      <%!-- <button phx-click="send_test_message">Send Test Message</button> --%>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      jid = %{
        sid: {socket.id, self()},
        username: socket.assigns.current_scope.user.username,
        host: %Najva{}.host,
        res: Integer.to_string(System.os_time(), 36)
      }

      Ejabberd.open_session(jid)
      Ejabberd.send_presence(jid)

      # Store these in the socket so we can close the session later
      {:ok, assign(socket, jid: jid)}
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_params(_params, url, socket) do
    {:noreply, assign(socket, current_path: url)}
  end

  # @impl true
  # def handle_event("send_test_message", _params, socket) do
  #   Ejabberd.send_test_message(socket.assigns.jid, "abir2@localhost", "Hello from Najva!")
  #   {:noreply, socket}
  # end

  @impl true
  def handle_info({:message, {chat_id, new_message}}, socket) do
    new_chat_list = Map.put(socket.assigns.chat_list, chat_id, new_message)
    {:noreply, assign(socket, chat_list: new_chat_list)}
  end

  # Catch-all for other PubSub messages
  @impl true
  def handle_info(msg, socket) do
    IO.inspect(msg, label: "ROOT HANDLE INFO")
    {:noreply, socket}
  end

  # This is called automatically when the user closes the tab or navigates away
  @impl true
  def terminate(_reason, socket), do: Ejabberd.close_session(socket.assigns.jid)
end
