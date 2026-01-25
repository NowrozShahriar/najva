defmodule NajvaWeb.SessionController do
  use NajvaWeb, :controller
  alias Najva.Auth

  def new(conn, _params) do
    render(conn, :new)
  end

  def login(conn, %{"jid" => jid, "password" => password}) do
    case Auth.login(jid, password) do
      {:ok, ciphertext} ->
        # "Save it in the cookies then reload page"
        conn
        |> put_resp_cookie("jid", jid, max_age: 60 * 60 * 24 * 30, http_only: true)
        |> put_resp_cookie("ciphertext", ciphertext,
          max_age: 60 * 60 * 24 * 30,
          http_only: true
        )
        |> put_session(:jid, jid)
        |> put_flash(:info, "Welcome back!")
        |> redirect(to: "/")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Incorrect JID or Password")
        |> render(:new)
    end
  end

  def logout(conn, _params) do
    conn
    |> clear_session()
    |> delete_resp_cookie("jid")
    |> delete_resp_cookie("ciphertext")
    |> redirect(to: "/login")
  end
end
