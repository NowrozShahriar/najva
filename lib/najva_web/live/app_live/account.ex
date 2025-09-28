defmodule NajvaWeb.AppLive.Account do
  use NajvaWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} live_action={@live_action}>
      <h1>Account</h1>
      <p>Check the console for debug information.</p>
    </Layouts.app>
    """
  end
end
