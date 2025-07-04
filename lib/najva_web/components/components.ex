defmodule NajvaWeb.Components do
  use Phoenix.Component

  @doc """
  Button component for Layouts.theme_toggle.

  ## Example

      <.theme_button theme={@theme} />
  """
  attr :theme, :string, required: true

  def theme_button(assigns) do
    ~H"""
    <button
      phx-click={Phoenix.LiveView.JS.dispatch("phx:set-theme", detail: %{theme: @theme})}
      class="flex p-2 cursor-pointer"
    >
      {@theme}
    </button>
    """
  end

  attr :themes, :list, required: true

  def theme_button(assigns) do
    ~H"""
    <button
      :for={theme <- @themes}
      phx-click={Phoenix.LiveView.JS.dispatch("phx:set-theme", detail: %{theme: theme})}
      class="flex p-2 cursor-pointer"
    >
      {theme}
    </button>
    """
  end

  # This component is used to hide the list pane on small screens.
  # It can be included in any LiveView or HTML template where you want to control the visibility of the list pane.
  attr :hide_class, :string, required: true
  attr :width, :string, default: "768px"

  def visibility(assigns) do
    ~H"""
    <style>
      @media (max-width: <%= @width %>) {
        .<%= @hide_class %> {
          display: none;
        }
      }
    </style>
    """
  end
end
