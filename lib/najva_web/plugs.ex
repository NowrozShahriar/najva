defmodule NajvaWeb.Plugs do
  import Plug.Conn
  import Phoenix.Controller

  alias Najva.Auth

  def auth_plug(conn, _opts) do
    jid = conn.cookies["jid"]
    ciphertext = conn.cookies["ciphertext"]

    if jid && ciphertext do
      case Auth.restore_session(jid, ciphertext) do
        :ok ->
          # Success: Ensure session is fresh and continue
          conn
          |> put_session(:jid, jid)
          |> assign(:current_user, jid)
          |> redirect_authenticated()

        {:error, :timeout} ->
          # Timeout: Don't clear session, just continue with a warning
          conn
          |> assign(:current_user, jid)
          |> put_flash(:warning, "Connection is slow. Some features may be unavailable.")

        {:error, _reason} ->
          # Auth failure: Clear cookies
          conn
          |> clear_session()
          |> delete_resp_cookie("jid")
          |> delete_resp_cookie("ciphertext")
          |> put_flash(:error, "Session expired. Please login again.")
      end
    else
      # No cookies found, continue. Not directly redirecting to login here to allow public routes.
      conn
    end
  end

  # Redirect authenticated users away from login/register pages
  defp redirect_authenticated(conn) do
    if conn.request_path == "/login" || conn.request_path == "/register" do
      conn
      |> redirect(to: "/")
      |> halt()
    else
      conn
    end
  end

  def require_auth(conn, _opts) do
    if get_session(conn, :jid) do
      # User is fully authenticated (session confirmed).
      conn
    else
      # User is NOT strictly logged in (or just timed out). Stop them.
      conn
      |> put_flash(:error, "You must be logged in to access that page.")
      |> redirect(to: "/login")
      |> halt()
    end
  end
end
