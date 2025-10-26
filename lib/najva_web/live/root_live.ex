defmodule NajvaWeb.RootLive do
  use NajvaWeb, :live_view
  alias Phoenix.PubSub

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      PubSub.subscribe(Najva.PubSub, "najva_test0@conversations.im")
      GenServer.call({:global, "najva_test0@conversations.im"}, :load_archive)
    end

    {:ok, assign(socket, chat_list: %{})}
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
end
