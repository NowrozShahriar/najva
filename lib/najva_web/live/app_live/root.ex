defmodule NajvaWeb.AppLive.Root do
  use NajvaWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      live_action={@live_action}
    >
      <%!-- <div class="chat-root m-1 text-white" /> --%>
    </Layouts.app>
    """
  end
end
