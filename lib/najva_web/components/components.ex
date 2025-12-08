defmodule NajvaWeb.Components do
  use Phoenix.Component
  import NajvaWeb.CoreComponents
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
      id={"theme-button-#{theme}"}
      phx-click={Phoenix.LiveView.JS.dispatch("phx:set-theme", detail: %{theme: theme})}
      class="theme-btn px-2 py-0.5 m-0.5 rounded-full cursor-pointer"
    >
      {theme}
    </button>
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

    navpanel_child = " m-0.5 size-11 rounded-xl p-1 "

    navpanel_child_active =
      " bg-accent text-accent-content hover:bg-accent hover:text-accent-content "

    navpanel_child_inactive =
      " hover:bg-neutral hover:text-neutral-content "

    navpanel_icon = " size-full " %>
    <nav class={navpanel}>
      
    <!-- All Chats -->
      <button
        phx-click="set_active_list"
        phx-value="all_chats"
        title="All chats"
        class={navpanel_child <> navpanel_child_active}
      >
        <.icon name="hero-chat-bubble-left-right" class={navpanel_icon} />
      </button>
      
    <!-- Inbox -->
      <button
        phx-click="set_active_list"
        phx-value="inbox"
        title="Inbox"
        class={navpanel_child <> navpanel_child_inactive}
      >
        <.icon name="hero-chat-bubble-oval-left-ellipsis" class={navpanel_icon} />
      </button>
      
    <!-- Groups -->
      <button
        phx-click="set_active_list"
        phx-value="groups"
        title="Groups"
        class={navpanel_child <> navpanel_child_inactive}
      >
        <.icon name="hero-user-group" class={navpanel_icon} />
      </button>
      
    <!-- Favorites -->
      <button
        phx-click="set_active_list"
        phx-value="favorites"
        title="Favorites"
        class={navpanel_child <> navpanel_child_inactive}
      >
        <.icon name="hero-heart" class={navpanel_icon} />
      </button>
      
    <!-- Archive (only visible on desktop) -->
      <button
        phx-click="set_active_list"
        phx-value="archive"
        title="Archive"
        class={navpanel_child <> " hidden sm:block" <> navpanel_child_inactive}
      >
        <.icon name="hero-archive-box" class={navpanel_icon} />
      </button>
      
    <!-- Contacts -->
      <button
        phx-click="set_active_list"
        phx-value="contacts"
        title="Contacts"
        class={navpanel_child <> navpanel_child_inactive}
      >
        <.icon name="hero-bookmark-square" class={navpanel_icon} />
      </button>
      
    <!-- Settings -->
      <.link
        patch={if @live_action != :settings, do: "/settings", else: "/"}
        id="settings-btn"
        title="Settings"
        class={
        navpanel_child <> " sm:mt-auto sm:mb-2" <> if @live_action != :settings, do: " hover:text-neutral-content hover:bg-neutral", else: " text-accent bg-base-200"
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

  def heading(assigns) do
    ~H"""
    <% header =
      " flex items-center justify-between pb-2 "

    title =
      " px-3 py-2 text-3xl font-bold "

    account_switcher =
      " border-base-100 min-w-0 hover:border-neutral mr-0.5 flex items-center rounded-xl border-2 py-1 pl-1.5 pr-0.5 "

    profile_icon =
      " size-11 flex-shrink-0 rounded-full border-2 "

    profile_icon_active =
      " border-accent bg-base-200 "

    profile_icon_inactive =
      " border-base-100 hover:border-neutral hover:bg-neutral hover:text-neutral-content "

    search_field =
      " bg-base-200 border-base-200 hover:border-neutral focus:border-accent w-full rounded-full border-2 px-4 py-1 focus:outline-none " %>

    <div class={header}>
      <.link navigate="/" class={title}>Najva</.link>

      <div class="flex min-w-0 items-center">
        <!-- Account switcher -->
        <button type="button" title="Switch accounts" class={account_switcher}>
          <p class={[
            "max-w-32 truncate pr-0.5 sm:max-w-48",
            @live_action != :root && " md:max-w-32 xl:max-w-48"
          ]}>
            jabberid@xmpp.server
          </p>
          <.icon name="hero-chevron-down" class="flex-shrink-0" />
        </button>
        
    <!-- Profile icon -->
        <.link
          patch="/login"
          id="account-btn"
          title="Account"
          class={profile_icon <> if @live_action != :profile, do: profile_icon_inactive, else: profile_icon_active}
        >
          <.icon name="hero-user-circle" class="size-full" />
        </.link>
      </div>
    </div>

    <!-- Search box -->
    <input type="text" placeholder="Search..." class={search_field} />
    <hr class="text-base-300 my-2" />
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
    <div class="flex-1 flex flex-col overflow-y-auto p-1 space-y-1">
      <div
        :for={{name, message} <- @chat_list}
        class="grid grid-cols-[auto_1fr_auto] gap-x-4 items-center px-3 py-2 sm:p-1 hover:bg-base-200 cursor-pointer rounded-2xl"
      >
        <div class="size-12 bg-secondary rounded-xl flex items-center justify-center text-primary-content font-bold text-xl">
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
    </div>
    """
  end

  # This component is used to hide the list pane on small screens.
  # It can be included in any LiveView or HTML template where you want to control the visibility of the list pane.
  #   attr :hide_class, :string, required: true
  #   attr :width, :string, default: "768px"
  #
  #   def visibility(assigns) do
  #     ~H"""
  #     <style>
  #       @media (max-width: <%= @width %>) {
  #         .<%= @hide_class %> {
  #           display: none;
  #         }
  #       }
  #     </style>
  #     """
  #   end
end
