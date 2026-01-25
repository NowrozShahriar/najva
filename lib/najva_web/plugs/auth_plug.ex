defmodule NajvaWeb.Plugs.AuthPlug do
  import Plug.Conn
  import Phoenix.Controller

  alias Najva.Auth

  def init(opts), do: opts

  def call(conn, _opts) do
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
end
