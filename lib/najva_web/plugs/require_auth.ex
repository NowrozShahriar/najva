defmodule NajvaWeb.Plugs.RequireAuth do
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    if conn.assigns[:current_user] do
      # User is logged in (AuthPlug did its job). Let them pass.
      conn
    else
      # User is NOT logged in. Stop them here.
      conn
      |> put_flash(:error, "You must be logged in to access that page.")
      |> redirect(to: "/login")
      |> halt()
    end
  end
end
