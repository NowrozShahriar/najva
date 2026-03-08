defmodule NajvaWeb.Pages do
  @moduledoc """
  Because the root("/") is going to be the only liveview users going to use other than the login, register and account settings pages, all the other pages are just going to be templates for the root liveview.
  So we are going to embed them here.
  """
  use NajvaWeb, :html
  import NajvaWeb.Components
  embed_templates "pages/*"
end
