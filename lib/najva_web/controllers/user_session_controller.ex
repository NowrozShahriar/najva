defmodule NajvaWeb.UserSessionController do
  use NajvaWeb, :controller

  alias Najva.Accounts
  alias NajvaWeb.UserAuth

  def login(conn, %{"_action" => "registered"} = params) do
    login(conn, params, "Account created successfully.")
  end

  def login(conn, %{"_action" => "confirmed"} = params) do
    login(conn, params, "User confirmed successfully.")
  end

  def login(conn, params) do
    login(conn, params, "Welcome back!")
  end

  # magic link login
  defp login(conn, %{"user" => %{"token" => token} = user_params}, info) do
    case Accounts.login_user_by_magic_link(token) do
      {:ok, {user, tokens_to_disconnect}} ->
        UserAuth.disconnect_sessions(tokens_to_disconnect)

        conn
        |> put_flash(:info, info)
        |> UserAuth.log_in_user(user, user_params)

      _ ->
        conn
        |> put_flash(:error, "The link is invalid or it has expired.")
        |> redirect(to: ~p"/log-in")
    end
  end

  # username + password login
  defp login(conn, %{"user" => user_params}, info) do
    %{"username" => username, "password" => password} = user_params

    if user = Accounts.get_user_by_username_and_password(username, password) do
      conn
      |> put_flash(:info, info)
      |> UserAuth.log_in_user(user, user_params)
    else
      # In order to prevent user enumeration attacks, don't disclose whether the username is registered.
      conn
      |> put_flash(:error, "Invalid username or password")
      |> redirect(to: ~p"/log-in")
    end
  end

  def update_password(conn, %{"user" => user_params} = params) do
    user = conn.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.update_user_password(user, user_params) do
      {:ok, %{user: _user, tokens: expired_tokens}} ->
        # disconnect all existing LiveViews with old sessions
        UserAuth.disconnect_sessions(expired_tokens)

      {:error, :user, changeset, _} ->
        {:error, changeset}

      {:error, _step, reason, _} ->
        {:error, reason}
    end

    conn
    |> put_session(:user_return_to, ~p"/settings")
    |> login(params, "Password updated successfully!")
  end

  def logout(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end

  def delete_account(conn, _params) do
    user = conn.assigns.current_scope.user
    Accounts.delete_user(user)

    conn
    |> put_flash(:info, "Account deleted successfully.")
    |> UserAuth.log_out_user()
  end
end
