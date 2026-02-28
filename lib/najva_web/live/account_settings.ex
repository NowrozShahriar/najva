defmodule NajvaWeb.Live.AccountSettings do
  use NajvaWeb, :live_view

  on_mount {NajvaWeb.UserAuth, :require_sudo_mode}

  alias Najva.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.flash_group flash={@flash} />
    <NajvaWeb.Components.heading live_action={@live_action} current_scope={@current_scope} />
    <div class="md:w-1/2 xl:w-1/3 mx-auto p-4">
      <div class="text-center">
        <.header>
          Account Settings
          <:subtitle>Manage your email address and password</:subtitle>
        </.header>
      </div>

      <.form for={@email_form} id="email_form" phx-submit="update_email" phx-change="validate_email">
        <.input
          field={@email_form[:email]}
          type="email"
          label="Email"
          autocomplete="username"
          required
        />
        <%= if @current_user.email do %>
          <.button variant="primary" phx-disable-with="Changing...">Change Email</.button>
        <% else %>
          <.button variant="primary" phx-disable-with="Saving...">Add Email</.button>
        <% end %>
      </.form>

      <div class="divider" />

      <.form
        for={@password_form}
        id="password_form"
        action={~p"/update-password"}
        method="post"
        phx-change="validate_password"
        phx-submit="update_password"
        phx-trigger-action={@trigger_submit}
      >
        <input
          name={@password_form[:username].name}
          type="hidden"
          id="hidden_username"
          autocomplete="username"
          value={@current_user.username}
        />
        <.input
          field={@password_form[:password]}
          type="password-toggle"
          label="New password"
          autocomplete="new-password"
          required
        />
        <.input
          field={@password_form[:password_confirmation]}
          type="password"
          label="Confirm new password"
          autocomplete="new-password"
        />
        <.button variant="primary" phx-disable-with="Saving...">
          Update Password
        </.button>
      </.form>

      <div class="divider" />

      <button
        class="btn btn-error btn-outline cursor-pointer"
        phx-click="show_delete_warning_modal"
      >
        Delete Account
      </button>

      <div id="delete_warning_modal" class={["modal", @show_delete_warning_modal && "modal-open"]}>
        <div class="modal-box w-auto">
          <h1 class="text-xl font-semibold text-center text-warning">Warning</h1>
          <p class="py-4 text-center">
            Are you sure you want to delete your account permanently? This action is immediate and cannot be undone.
          </p>
          <div class="modal-action flex justify-end">
            <button
              class="btn btn-warning mr-2"
              phx-click="show_delete_confirm_modal"
            >
              Continue
            </button>
            <button class="btn btn-accent ml-2" phx-click="close_delete_modals">Close</button>
          </div>
        </div>
        <div class="modal-backdrop" phx-click="close_delete_modals">
          <button class="cursor-default">close</button>
        </div>
      </div>

      <div id="delete_confirm_modal" class={["modal", @show_delete_confirm_modal && "modal-open"]}>
        <div class="modal-box w-auto">
          <h1 class="text-xl font-semibold text-center text-error">Confirm Deletion</h1>
          <p class="py-4 text-center">Type your username "{@current_user.username}" to confirm.</p>
          <form phx-change="validate_delete_account" onsubmit="event.preventDefault();">
            <input
              type="text"
              name="username"
              value={@delete_username_input}
              placeholder="Username"
              class="input input-bordered w-full"
              autocomplete="off"
            />
          </form>
          <div class="modal-action">
            <div class="flex justify-end w-full">
              <%= if @delete_username_input == @current_user.username do %>
                <.link class="btn btn-error mr-2" href={~p"/settings/account"} method="delete">
                  Delete
                </.link>
              <% else %>
                <button class="btn btn-error mr-2 btn-disabled" disabled>
                  Delete
                </button>
              <% end %>
              <button class="btn btn-accent ml-2" phx-click="close_delete_modals">Cancel</button>
            </div>
          </div>
        </div>
        <div class="modal-backdrop" phx-click="close_delete_modals">
          <button class="cursor-default">close</button>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_scope.user, token) do
        {:ok, _user} ->
          put_flash(socket, :info, "Email confirmed successfully.")

        {:error, _} ->
          put_flash(socket, :error, "The confirmation link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/settings")}
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    email_changeset = Accounts.validate_email_input(user, %{}, validate_unique: false)
    password_changeset = Accounts.validate_password_input(user, %{}, hash_password: false)

    socket =
      socket
      |> assign(:current_user, user)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:trigger_submit, false)
      |> assign(:delete_username_input, "")
      |> assign(:show_delete_warning_modal, false)
      |> assign(:show_delete_confirm_modal, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate_email", params, socket) do
    %{"user" => user_params} = params

    email_form =
      socket.assigns.current_scope.user
      |> Accounts.validate_email_input(user_params, validate_unique: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form)}
  end

  def handle_event("update_email", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.validate_email_input(user, user_params) do
      %{valid?: true} = changeset ->
        Accounts.deliver_user_confirm_email_instructions(
          Ecto.Changeset.apply_action!(changeset, :insert),
          "email:#{user.email || user.username}",
          &url(~p"/settings/confirm-email/#{&1}")
        )

        info = "A confirmation link has been sent to the given email address."
        {:noreply, socket |> put_flash(:info, info)}

      changeset ->
        {:noreply, assign(socket, :email_form, to_form(changeset, action: :insert))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"user" => user_params} = params

    password_form =
      socket.assigns.current_scope.user
      |> Accounts.validate_password_input(user_params, hash_password: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form)}
  end

  def handle_event("update_password", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.validate_password_input(user, user_params) do
      %{valid?: true} = changeset ->
        {:noreply, assign(socket, trigger_submit: true, password_form: to_form(changeset))}

      changeset ->
        {:noreply, assign(socket, password_form: to_form(changeset, action: :insert))}
    end
  end

  def handle_event("validate_delete_account", %{"username" => username}, socket) do
    {:noreply, assign(socket, :delete_username_input, username)}
  end

  def handle_event("show_delete_warning_modal", _, socket) do
    {:noreply,
     assign(socket,
       show_delete_warning_modal: true,
       show_delete_confirm_modal: false,
       delete_username_input: ""
     )}
  end

  def handle_event("show_delete_confirm_modal", _, socket) do
    {:noreply,
     assign(socket,
       show_delete_warning_modal: false,
       show_delete_confirm_modal: true,
       delete_username_input: ""
     )}
  end

  def handle_event("close_delete_modals", _, socket) do
    {:noreply,
     assign(socket,
       show_delete_warning_modal: false,
       show_delete_confirm_modal: false,
       delete_username_input: ""
     )}
  end
end
