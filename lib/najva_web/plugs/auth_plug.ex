defmodule NajvaWeb.Plugs.AuthPlug do
  import Plug.Conn
  import Phoenix.Controller

  alias Najva.Auth

  def init(opts), do: opts

  def call(conn, _opts) do
    jid = get_session(conn, :jid) || conn.cookies["jid"]

    encrypted_password =
      get_session(conn, :encrypted_password) || conn.cookies["encrypted_password"]

    if jid && encrypted_password do
      case Auth.restore_session(jid, encrypted_password) do
        :ok ->
          # Success: Ensure session is fresh and continue
          conn
          |> put_session(:jid, jid)
          |> assign(:current_user, jid)

        {:error, _reason} ->
          # Failure: "Remove cookies then reload page"
          conn
          |> clear_session()
          |> delete_resp_cookie("jid")
          |> delete_resp_cookie("encrypted_password")
          |> put_flash(:error, "Session expired. Please login again.")
          # Redirect effectively reloads the context
          |> redirect(to: "/login")
          |> halt()
      end
    else
      # No cookies found, continue (let Controller/LiveView handle auth requirements)
      conn
    end
  end
end
