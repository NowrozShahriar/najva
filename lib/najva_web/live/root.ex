defmodule NajvaWeb.Live.Root do
  use NajvaWeb, :live_view

  @impl true
  def mount(_params, session, socket) do
    jid = session["jid"]

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Najva.PubSub, jid)

      case Horde.Registry.lookup(Najva.HordeRegistry, jid) do
        [{pid, _}] ->
          GenServer.cast(pid, :load_archive)

        [] ->
          :ok
      end
    end

    {:ok, assign(socket, chat_list: %{}, current_user: jid)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      live_action={@live_action}
      chat_list={@chat_list}
      current_user={@current_user}
    >
      <div :if={@live_action == :profile}>
        <h1>Account</h1>
        <p>Check the console for debug information.</p>
      </div>
      <div :if={@live_action == :settings} class="lg:w-2/3 xl:w-1/2 mx-auto">
        <h1 class="font-semibold text-2xl p-4">Settings</h1>
        <Layouts.theme_toggle />
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_params(_params, url, socket) do
    {:noreply, assign(socket, current_path: url)}
  end

  @impl true
  def handle_info({:authenticated, _}, socket), do: {:noreply, socket}

  @impl true
  def handle_info(:authenticated, socket), do: {:noreply, socket}

  @impl true
  def handle_info({:mam_finished, chat_map}, socket) do
    #     chat_list =
    #       chat_map
    #       |> Map.values()
    #       |> Enum.sort_by(& &1.time, :desc)
    #
    #     IO.inspect(chat_list, label: "MAM FINISHED - CHAT LIST")
    {:noreply, assign(socket, chat_list: chat_map)}
  end

  @impl true
  def handle_info({:message, {chat_id, new_message}}, socket) do
    new_chat_list = Map.put(socket.assigns.chat_list, chat_id, new_message)
    {:noreply, assign(socket, chat_list: new_chat_list)}
  end

  # Catch-all for other PubSub messages
  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}
end
