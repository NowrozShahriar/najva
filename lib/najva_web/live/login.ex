defmodule NajvaWeb.Live.Login do
  use NajvaWeb, :live_view

  alias Najva.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.flash_group flash={@flash} />
    <NajvaWeb.Components.heading live_action={@live_action} current_scope={@current_scope} />
    <div class="mx-auto max-w-sm space-y-4 my-8 p-2">
      <div class="text-center">
        <%= if @current_scope do %>
          <.header>
            <h1 class="text-2xl">Reauthenticate</h1>
          </.header>
        <% else %>
          <.header>
            <h1 class="text-2xl">Log in</h1>
            <:subtitle>
              Don't have an account? <.link
                navigate={~p"/register"}
                class="font-semibold text-brand underline"
                phx-no-format
              >Sign up</.link>
            </:subtitle>
          </.header>
        <% end %>
      </div>

      <.form
        :let={f}
        :if={@live_action == :login}
        for={@form}
        id="login_form_password"
        action={~p"/log-in"}
        phx-submit="submit_password"
        phx-trigger-action={@trigger_submit}
      >
        <.input
          readonly={!!@current_scope}
          field={f[:username]}
          type="text"
          label="Username"
          autocomplete="username"
          required
        />
        <.input
          field={@form[:password]}
          type="password-toggle"
          label="Password"
          autocomplete="current-password"
        />
        <.button class="btn btn-primary w-full" name={@form[:remember_me].name} value="true">
          Log in <span aria-hidden="true">→</span>
        </.button>
        <%= if !@current_scope do %>
          <.button class="btn btn-primary btn-soft w-full mt-2">
            Log in only this time
          </.button>
        <% end %>
        <.link
          patch={~p"/forgot-password"}
          class="btn btn-ghost text-base-content/70 w-full mt-2 underline"
        >
          Forgot password?
        </.link>
      </.form>

      <.form
        :let={f}
        :if={@live_action == :forgot_password}
        for={@form}
        id="login_form_magic"
        action={~p"/log-in"}
        phx-submit="submit_magic"
      >
        <.input
          readonly={!!@current_scope}
          field={f[:email]}
          type="email"
          label="Email"
          autocomplete="email"
          required
          phx-mounted={JS.focus()}
        />
        <.button class="btn btn-primary w-full">
          Log in with email <span aria-hidden="true">→</span>
        </.button>
      </.form>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    username =
      Phoenix.Flash.get(socket.assigns.flash, :username) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:username)])

    email = get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"username" => username, "email" => email}, as: "user")

    {:ok, assign(socket, form: form, trigger_submit: false)}
  end

  @impl true
  def handle_params(_params, url, socket) do
    {:noreply, assign(socket, current_path: url)}
  end

  @impl true
  def handle_event("submit_password", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end

  def handle_event("submit_magic", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_login_instructions(
        user,
        &url(~p"/log-in/#{&1}")
      )
    end

    info =
      "If your email is in our system, you will receive instructions for logging in shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> push_navigate(to: ~p"/log-in")}
  end
end
