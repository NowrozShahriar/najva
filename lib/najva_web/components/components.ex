defmodule NajvaWeb.Components do
  use NajvaWeb, :html
  #   @doc """
  #   Button component for Layouts.theme_toggle.
  #
  #   ## Example
  #
  #       <.theme_button theme={@theme} />
  #   """
  #   attr :theme, :string, required: true
  #
  #   def theme_button(assigns) do
  #     ~H"""
  #     <button
  #       phx-click={Phoenix.LiveView.JS.dispatch("phx:set-theme", detail: %{theme: @theme})}
  #       class="flex p-2 cursor-pointer"
  #     >
  #       {@theme}
  #     </button>
  #     """
  #   end

  @doc """
  buttons from list for Layouts.theme_toggle.

  ## Example

      <.theme_buttons themes={["garden", "forest"]} />
  """
  attr :themes, :list, required: true

  def theme_buttons(assigns) do
    ~H"""
    <button
      :for={theme <- @themes}
      id={"theme-button-" <> theme}
      data-phx-theme={theme}
      phx-click={Phoenix.LiveView.JS.dispatch("phx:set-theme")}
      class="theme-btn px-2 py-0.5 m-0.5 rounded-full cursor-pointer"
    >
      {theme}
    </button>
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
      <button
        id="theme-button-system"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
        class="theme-btn px-2 py-0.5 m-0.5 rounded-full cursor-pointer"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        id="theme-button-light"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
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
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
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

  @doc """
  """
  attr :live_action, :atom, required: true
  # attr :active_list, :atom, required: true

  def navbar(assigns) do
    ~H"""
    <!-- Navigation bar: vertical on desktop, horizontal on mobile -->
    <% navpanel =
      " bg-base-100 mt-0.5 flex justify-evenly p-0.5 sm:py4 sm:m-0.5 sm:flex-col sm:justify-normal sm:rounded-lg "

    navpanel_child =
      " m-0.5 size-11 p-1.5 "

    navpanel_child_active =
      " btn-primary bg-transparent text-primary "

    navpanel_child_inactive =
      " hover:text-base-content/75 "

    navpanel_icon = " size-full " %>
    <nav class={navpanel}>
      
    <!-- Posts -->
      <.link
        patch="/"
        title="Posts"
        class={navpanel_child <> if @live_action == :root, do: navpanel_child_active, else: navpanel_child_inactive}
      >
        <.icon name="hero-newspaper" class={navpanel_icon} />
      </.link>
      
    <!-- Messages -->
      <.link
        patch="/messages"
        title="Messages"
        class={navpanel_child <> " md:hidden" <> if @live_action == :messages, do: navpanel_child_active, else: navpanel_child_inactive}
      >
        <.icon name="hero-chat-bubble-oval-left-ellipsis" class={navpanel_icon} />
      </.link>
      
    <!-- Contacts -->
      <.link
        patch="/contacts"
        title="Contacts"
        class={navpanel_child <> if @live_action == :contacts, do: navpanel_child_active, else: navpanel_child_inactive}
      >
        <.icon name="hero-user-group" class={navpanel_icon} />
      </.link>
      
    <!-- Favorites -->
      <button
        title="Favorites"
        class={navpanel_child <> navpanel_child_inactive}
      >
        <.icon name="hero-heart" class={navpanel_icon} />
      </button>
      
    <!-- Archive (only visible on desktop) -->
      <button
        title="Archive"
        class={navpanel_child <> " hidden sm:block" <> navpanel_child_inactive}
      >
        <.icon name="hero-archive-box" class={navpanel_icon} />
      </button>
      
    <!-- Saved -->
      <button
        title="Saved"
        class={navpanel_child <> " hidden sm:block" <> navpanel_child_inactive}
      >
        <.icon name="hero-bookmark-square" class={navpanel_icon} />
      </button>
      
    <!-- Settings -->
      <.link
        patch="/settings"
        id="settings-btn"
        title="Settings"
        class={
        navpanel_child <> " sm:mt-auto sm:mb-2" <> if @live_action != :settings, do: navpanel_child_inactive, else: navpanel_child_active
      }
      >
        <.icon name="hero-cog-6-tooth" class={navpanel_icon} />
      </.link>
    </nav>
    """
  end

  @doc """

  """
  attr :live_action, :atom, required: true
  attr :current_scope, :map, required: true
  attr :class, :any, default: nil

  def heading(assigns) do
    ~H"""
    <% header =
      " flex items-center justify-between pb-2 "

    title =
      " px-2 text-3xl font-bold "

    account_switcher =
      " border-base-100 min-w-0 mr-0.5 flex items-center rounded-xl p-1 "

    profile_icon =
      " size-11 flex-shrink-0 rounded-full border-2 "

    profile_icon_active =
      " border-primary bg-base-200 "

    profile_icon_inactive =
      " border-base-100 hover:border-neutral hover:bg-neutral hover:text-neutral-content "

    # search_field =
    #   " bg-base-200 border-base-200 hover:border-neutral focus:border-primary w-full rounded-full border-2 px-4 py-1 focus:outline-none " %>

    <div class={[header, @class]}>
      <.link patch="/" class={title}>Najva</.link>

      <div :if={@current_scope} class="flex min-w-0 items-center p-1">
        <button class={account_switcher}>
          <p class={[
            "max-w-32 truncate pr-0.5 sm:max-w-48",
            @live_action != :root && " md:max-w-32 xl:max-w-48"
          ]}>
            {@current_scope.user.username}
          </p>
          <%!-- <.icon name="hero-chevron-down" class="flex-shrink-0" /> --%>
        </button>
        
    <!-- Profile icon -->
        <.link
          patch="/profile"
          id="account-btn"
          title="Account"
          class={profile_icon <> if @live_action != :profile, do: profile_icon_inactive, else: profile_icon_active}
        >
          <.icon name="hero-user-circle" class="size-full" />
        </.link>
      </div>
    </div>

    <!-- Search box -->
    <%!-- <input type="text" placeholder="Search..." class={search_field} /> --%>
    <%!-- <hr class="text-base-300 my-2" /> --%>
    """
  end

  @doc """
  Renders a list of chats in the list pane.
  It expects a map of chats where keys are JIDs and values are maps
  containing chat details like `:name`, `:last_message`, and `:timestamp`.

  ## Example

      <.list_chats chat_list={@chat_list} />
  """

  attr :chat_list, :map, required: true

  def list_chats(assigns) do
    ~H"""
    <ul class="list overflow-y-auto p-1 space-y-1">
      <li class="list-row gap-2 p-2 hover:bg-base-200 items-center">
        <div class="">
          <%!-- <img
            class="size-10 rounded-box"
            src="https://img.daisyui.com/images/profile/demo/1@94.webp"
          /> --%>
          <div class="size-12 bg-secondary rounded-full flex items-center justify-center text-primary-content font-bold text-xl">
            {String.at("Dio Lupa", 0)}
          </div>
        </div>
        <div class="flex flex-col gap-1 overflow-hidden">
          <div>Dio Lupa</div>
          <div class="opacity-60 truncate">
            Remaining Reason
          </div>
        </div>
        <button class=" bg-transparent h-full w-5">
          <.icon name="hero-ellipsis-vertical" class="size-full" />
        </button>
      </li>
    </ul>
    <%!-- <div class="flex-1 flex flex-col overflow-y-auto p-1 space-y-1">
      <div
        :for={{name, message} <- @chat_list}
        class="grid grid-cols-[auto_1fr_auto] gap-x-4 items-center px-3 py-2 sm:p-1 hover:bg-base-200 cursor-pointer rounded-2xl"
      >
        <div class="size-12 bg-secondary mask mask-squircle flex items-center justify-center text-primary-content font-bold text-xl">
          {String.at(name, 0)}
        </div>
        <div class="flex flex-col overflow-hidden">
          <div class="font-bold">{name}</div>
          <div class="text-sm truncate">{message.text}</div>
        </div>
        <div class="text-xs self-start pt-1">
          {message.time |> DateTime.from_unix!(:microsecond) |> Calendar.strftime("%H:%M")}
        </div>
      </div>
    </div> --%>
    """
  end
end
