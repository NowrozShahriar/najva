defmodule NajvaWeb.Plugs.RequireAuth do
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
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
