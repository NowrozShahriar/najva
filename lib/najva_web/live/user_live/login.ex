defmodule NajvaWeb.UserLive.Login do
  use NajvaWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm space-y-4 my-8 p-2">
      <div class="text-center">
        <.header>
          <h1 class="text-2xl">Log in</h1>
          <:subtitle>
            Don't have an account? <.link
              navigate={~p"/users/register"}
              class="font-semibold text-brand underline"
              phx-no-format
            >Sign up</.link>
          </:subtitle>
        </.header>
      </div>

      <.form
        :let={f}
        for={@form}
        id="login_form_password"
        action={~p"/users/log-in"}
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
        <.button class="btn btn-primary btn-soft w-full mt-2">
          Log in only this time
        </.button>
      </.form>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email}, as: "user")

    {:ok, assign(socket, form: form, trigger_submit: false)}
  end

  @impl true
  def handle_event("submit_password", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end
end
