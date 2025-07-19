defmodule NajvaWeb.AppLive.Root do
  use NajvaWeb, :live_view

  # @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       active_list: :all_chats,
       active_jid: nil,
       chat_list: Najva.listpane_content()
     )}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} live_action={@live_action} active_list={@active_list} chat_list={@chat_list}>
      <%!-- <div class="chat-root m-1 text-white" /> --%>
    </Layouts.app>
    """
  end
end
