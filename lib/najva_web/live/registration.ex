defmodule NajvaWeb.Live.Registration do
  use NajvaWeb, :live_view

  alias Najva.Accounts
  alias Najva.Accounts.User

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm my-8 p-2">
      <div class="text-center">
        <.header>
          <h1 class="text-2xl">Create a new account</h1>
          <:subtitle>
            Already have an account?
            <.link navigate={~p"/log-in"} class="font-semibold text-brand underline">
              Log in
            </.link>
          </:subtitle>
        </.header>
      </div>

      <.form
        for={@form}
        id="registration_form"
        phx-submit="save"
        phx-change="validate"
        phx-trigger-action={@trigger_submit}
        action={~p"/log-in"}
      >
        <input name="_action" value="registered" type="hidden" />
        <.input
          field={@form[:username]}
          type="text"
          label="Username"
          autocomplete="username"
          required
          phx-mounted={JS.focus()}
        />

        <p class="text-sm text-zinc-500 mt-2">
          <.icon name="hero-exclamation-triangle-mini" class="size-4 inline-block" />
          Username cannot be changed later.
        </p>

        <.input
          field={@form[:password]}
          type="password-toggle"
          label="Password"
          autocomplete="new-password"
          required
        />

        <.input
          field={@form[:password_confirmation]}
          type="password"
          label="Confirm password"
          autocomplete="new-password"
          required
        />

        <p class="text-sm text-zinc-500 mt-2">
          <.icon name="hero-exclamation-triangle-mini" class="size-4 inline-block" />
          Account cannot be recovered if password is lost, unless you add a recovery email.
        </p>

        <.button phx-disable-with="Creating account..." class="btn btn-primary w-full">
          Register
        </.button>
      </.form>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    {:ok, redirect(socket, to: NajvaWeb.UserAuth.signed_in_path(socket))}
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.validate_registration_form(%User{}, %{}, validate_unique: false)

    {:ok, assign_form(socket, changeset) |> assign(trigger_submit: false),
     temporary_assigns: [form: nil]}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user_with_password(user_params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> assign(trigger_submit: true)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.validate_registration_form(%User{}, user_params, validate_unique: false)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end
end
