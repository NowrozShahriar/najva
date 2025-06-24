defmodule NajvaWeb.Components do
  use Phoenix.Component

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
