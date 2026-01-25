defmodule NajvaWeb.LoginLive do
  use NajvaWeb, :live_view

  def mount(_params, _session, socket) do
    # Set trigger_submit to false initially
    {:ok, assign(socket, form: to_form(%{}), trigger_submit: false)}
  end

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm p-6">
      <h1 class="text-2xl font-bold mb-4 text-center">Login to Najva</h1>
      
    <!--
        KEY PART: phx-trigger-action={@trigger_submit}
        If this becomes true, LiveView submits a real HTML POST request.
        action={~p"/login"} points to the standard SessionController.
      -->
      <.form
        for={@form}
        id="login-form"
        action={~p"/login"}
        phx-submit="submit"
        phx-change="validate"
        phx-trigger-action={@trigger_submit}
        method="post"
      >
        <.input
          field={@form[:jid]}
          type="text"
          label="Jabber ID (JID)"
          placeholder="user@example.com"
          required
        />
        <.input field={@form[:password]} type="password" label="Password" required />

        <div class="mt-4">
          <.button phx-disable-with="Logging in..." class="w-full">Login</.button>
        </div>
      </.form>

      <div class="mt-4 text-center text-sm">
        <p>
          Don't have an account?
          <.link navigate={~p"/register"} class="text-blue-500 hover:underline">Register</.link>
        </p>
      </div>
    </div>
    """
  end

  # Real-time validation (Optional but nice UX)
  def handle_event("validate", %{"jid" => _jid, "password" => _password}, socket) do
    # You could add logic here to check if JID format is valid regex-wise
    {:noreply, socket}
  end

  # When user clicks Submit
  def handle_event("submit", _params, socket) do
    # We don't do the login logic here. We just validate constraints if needed.
    # Then we flip `trigger_submit` to true.
    # This tells the browser: "Okay, submit this form for real now using HTTP POST."
    {:noreply, assign(socket, trigger_submit: true)}
  end
end
