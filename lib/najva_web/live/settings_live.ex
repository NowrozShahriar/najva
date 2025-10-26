defmodule NajvaWeb.SettingsLive do
  use NajvaWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} live_action={@live_action}>
      <div class="lg:w-2/3 xl:w-1/2 mx-auto">
        <h1 class="font-semibold text-2xl p-4">Settings</h1>
        <Layouts.theme_toggle />
      </div>
    </Layouts.app>
    """
  end
end
