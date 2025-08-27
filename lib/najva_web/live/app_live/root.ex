defmodule NajvaWeb.AppLive.Root do
  use NajvaWeb, :live_view

  # @impl true
  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(Najva.PubSub, "messages:all")

    messages = Najva.MessageStore.list_messages(100)

    {:ok,
     assign(socket,
       active_list: :all_chats,
       active_jid: nil,
       chat_list: Najva.listpane_content(),
       messages: messages
     )}
  end

  @impl true
  def handle_info({:new_message, msg}, socket) do
    {:noreply, update(socket, :messages, fn messages -> [msg | messages] |> Enum.take(200) end)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      live_action={@live_action}
      active_list={@active_list}
      chat_list={@chat_list}
    >
      <%!-- <div class="chat-root m-1 text-white" /> --%>
    </Layouts.app>
    """
  end
end
