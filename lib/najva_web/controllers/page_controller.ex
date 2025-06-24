defmodule NajvaWeb.PageController do
  use NajvaWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
