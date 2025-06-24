defmodule NajvaWeb.AppLive.Root do
  use NajvaWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="chat-root m-1 text-white" />
    """
  end
end
