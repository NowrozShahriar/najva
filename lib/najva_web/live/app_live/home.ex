defmodule NajvaWeb.AppLive.Home do
  use NajvaWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="text-white">
      <.link navigate="/">Home</.link>
      <p>Check the console for debug information.</p>
    </div>
    <NajvaWeb.Components.visibility hide_class="listpane" />
    """
  end
end
