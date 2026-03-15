defmodule NajvaWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use NajvaWeb, :html
  import NajvaWeb.Components

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  The main layout for the application.
  """
  attr :live_action, :atom, required: true
  attr :current_scope, :map, required: true
  slot :listpane_content, required: true
  slot :inner_block

  def app(assigns) do
    ~H"""
    <% main_container =
      " bg-base-200/30 mx-auto flex h-dvh max-w-screen-2xl flex-col-reverse sm:flex-row sm:p-0.5 " %>
    <main class={main_container}>
      <.navbar live_action={@live_action} />
      <.listpane live_action={@live_action} current_scope={@current_scope}>
        {render_slot(@listpane_content)}
      </.listpane>
      
    <!-- MainPanel -->
      <% mainpanel =
        " size-full sm:m-0.5 sm:h-auto sm:rounded-lg p-1 " <>
          if @live_action in [:messages, :contacts, :favourites, :saved, :archive],
            do: " hidden md:block ",
            else: "" %>
      <div class={mainpanel}>
        <.heading
          :if={@live_action == :root}
          class=" md:hidden p-1 "
          live_action={@live_action}
          current_scope={@current_scope}
        />
        {render_slot(@inner_block)}
      </div>
    </main>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end
end
