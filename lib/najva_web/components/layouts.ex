defmodule NajvaWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered as part of the
  application router. The "app" layout is rendered as component
  in regular views and live views.
  """
  import NajvaWeb.Components
  use NajvaWeb, :html

  embed_templates "layouts/*"

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

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div
      id="theme-manager"
      phx-hook="ThemeIndicator"
      class=" flex flex-wrap items-center bg-base-200 rounded-2xl p-2"
    >
      <%!-- <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" /> --%>

      <button
        id="theme-button-system"
        phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "system"})}
        class="theme-btn px-2 py-0.5 m-0.5 rounded-full cursor-pointer"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
      <button
        id="theme-button-light"
        phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "light"})}
        class="theme-btn px-2 py-0.5 m-0.5 rounded-full cursor-pointer"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" /> light
      </button>

      <% light_themes = [
        "cupcake",
        "bumblebee",
        "emerald",
        "corporate",
        "retro",
        "cyberpunk",
        "valentine",
        "garden",
        "lofi",
        "pastel",
        "fantasy",
        "wireframe",
        "cmyk",
        "autumn",
        "acid",
        "lemonade",
        "winter",
        "nord",
        "caramellatte",
        "silk"
      ] %>
      <.theme_buttons themes={light_themes} />

      <button
        id="theme-button-dark"
        phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "dark"})}
        class="theme-btn px-2 py-0.5 m-0.5 rounded-full cursor-pointer"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" /> dark
      </button>

      <% dark_themes = [
        "synthwave",
        "halloween",
        "forest",
        "aqua",
        "black",
        "luxury",
        "dracula",
        "business",
        "night",
        "coffee",
        "dim",
        "sunset",
        "abyss"
      ] %>
      <.theme_buttons themes={dark_themes} />
    </div>
    """
  end
end
