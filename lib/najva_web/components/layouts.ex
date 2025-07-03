defmodule NajvaWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered as part of the
  application router. The "app" layout is rendered as component
  in regular views and live views.
  """
  use NajvaWeb, :html

  embed_templates "layouts/*"

  #   attr :flash, :map, required: true, doc: "the map of flash messages"
  #
  #   attr :current_scope, :map,
  #     default: nil,
  #     doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"
  #
  #   slot :inner_block, required: true
  #
  #   def app(assigns) do
  #     ~H"""
  #     <header class="navbar px-4 sm:px-6 lg:px-8">
  #       <div class="flex-1">
  #         <a href="/" class="flex-1 flex w-fit items-center gap-2">
  #           <img src={~p"/images/logo.svg"} width="36" />
  #           <span class="text-sm font-semibold">v{Application.spec(:phoenix, :vsn)}</span>
  #         </a>
  #       </div>
  #       <div class="flex-none">
  #         <ul class="flex flex-column px-1 space-x-4 items-center">
  #           <li>
  #             <a href="https://phoenixframework.org/" class="btn btn-ghost">Website</a>
  #           </li>
  #           <li>
  #             <a href="https://github.com/phoenixframework/phoenix" class="btn btn-ghost">GitHub</a>
  #           </li>
  #           <li>
  #             <.theme_toggle />
  #           </li>
  #           <li>
  #             <a href="https://hexdocs.pm/phoenix/overview.html" class="btn btn-primary">
  #               Get Started <span aria-hidden="true">&rarr;</span>
  #             </a>
  #           </li>
  #         </ul>
  #       </div>
  #     </header>
  #
  #     <main class="px-4 py-20 sm:px-6 lg:px-8">
  #       <div class="mx-auto max-w-2xl space-y-4">
  #         {render_slot(@inner_block)}
  #       </div>
  #     </main>
  #     """
  #   end

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
    <div class=" flex flex-wrap items-center bg-base-200 rounded-2xl p-2">
      <%!-- <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" /> --%>

      <button
        phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "system"})}
        class="flex p-2 cursor-pointer"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "light"})}
        class="flex p-2 cursor-pointer"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "dark"})}
        class="flex p-2 cursor-pointer"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
      <button
        phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "cupcake"})}
        class="flex p-2 cursor-pointer"
      >
        cupcake
      </button>
      <button
        phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "bumblebee"})}
        class="flex p-2 cursor-pointer"
      >
        bumblebee
      </button>
      <button
        phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "corporate"})}
        class="flex p-2 cursor-pointer"
      >
        corporate
      </button>
      <button
        phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "garden"})}
        class="flex p-2 cursor-pointer"
      >
        garden
      </button>
      <button
        phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "pastel"})}
        class="flex p-2 cursor-pointer"
      >
        pastel
      </button>
      <button
        phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "wireframe"})}
        class="flex p-2 cursor-pointer"
      >
        wireframe
      </button>
      <button
        phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "cmyk"})}
        class="flex p-2 cursor-pointer"
      >
        cmyk
      </button>
      <button
        phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "autumn"})}
        class="flex p-2 cursor-pointer"
      >
        autumn
      </button>
      <button
        phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "nord"})}
        class="flex p-2 cursor-pointer"
      >
        nord
      </button>
      <button
        phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "caramellatte"})}
        class="flex p-2 cursor-pointer"
      >
        caramellatte
      </button>
      <button
        phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "retro"})}
        class="flex p-2 cursor-pointer"
      >
        retro
      </button>
      <button
        phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "business"})}
        class="flex p-2 cursor-pointer"
      >
        business
      </button>
      <button
        phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "halloween"})}
        class="flex p-2 cursor-pointer"
      >
        halloween
      </button>
      <button
        phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "forest"})}
        class="flex p-2 cursor-pointer"
      >
        forest
      </button>
      <button
        phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "black"})}
        class="flex p-2 cursor-pointer"
      >
        black
      </button>
      <button
        phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "luxury"})}
        class="flex p-2 cursor-pointer"
      >
        luxury
      </button>
      <button
        phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "dracula"})}
        class="flex p-2 cursor-pointer"
      >
        dracula
      </button>
      <button
        phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "night"})}
        class="flex p-2 cursor-pointer"
      >
        night
      </button>
      <button
        phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "coffee"})}
        class="flex p-2 cursor-pointer"
      >
        coffee
      </button>
      <button
        phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "dim"})}
        class="flex p-2 cursor-pointer"
      >
        dim
      </button>
      <button
        phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "sunset"})}
        class="flex p-2 cursor-pointer"
      >
        sunset
      </button>
      <button
        phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "abyss"})}
        class="flex p-2 cursor-pointer"
      >
        abyss
      </button>
    </div>
    <NajvaWeb.Components.visibility hide_class="listpane" />
    """
  end
end
