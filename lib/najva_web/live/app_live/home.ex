defmodule NajvaWeb.AppLive.Home do
  use NajvaWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} live_action={@live_action}>
      <.link navigate="/">Home</.link>
      <p>Check the console for debug information.</p>
    </Layouts.app>
    <%!-- <NajvaWeb.Components.visibility hide_class="listpane" /> --%>
    """
  end
end
