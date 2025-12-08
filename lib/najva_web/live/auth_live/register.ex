defmodule NajvaWeb.AuthLive.Register do
  use NajvaWeb, :live_view

  # Stub for checking availability (Move to your Context)
  # def check_availability(jid), do: ...

  def mount(_params, _session, socket) do
    # meaningful changeset logic would go here
    changeset = %{}
    {:ok, assign(socket, form: to_form(changeset), trigger_submit: false)}
  end

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm p-6">
      <h1 class="text-2xl font-bold mb-4 text-center">Create Account</h1>

      <.form
        for={@form}
        id="register-form"
        action={~p"/register"}
        phx-submit="save"
        phx-change="validate"
        phx-trigger-action={@trigger_submit}
        method="post"
      >
        <.input field={@form[:jid]} type="text" label="Desired JID" required />
        <.input field={@form[:password]} type="password" label="Password" required />
        <.input field={@form[:password_confirm]} type="password" label="Confirm Password" required />

        <div class="mt-4">
          <.button phx-disable-with="Creating..." class="w-full">Register</.button>
        </div>
      </.form>
    </div>
    """
  end

  def handle_event("validate", %{"jid" => _jid} = _params, socket) do
    # Here you can implement "Username taken" logic
    # changeset = Accounts.change_registration(params)
    # {:noreply, assign(socket, form: to_form(changeset))}
    {:noreply, socket}
  end

  def handle_event("save", _params, socket) do
    # If validation passes, trigger the POST to controller
    {:noreply, assign(socket, trigger_submit: true)}
  end
end
