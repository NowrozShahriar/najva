defmodule NajvaWeb.Router do
  use NajvaWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {NajvaWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", NajvaWeb do
    pipe_through :browser

    live "/", RootLive, :root
    live "/profile", RootLive, :profile
    live "/settings", RootLive, :settings
  end

  scope "/", NajvaWeb do
    pipe_through :browser

    live "/login", AuthLive.Login, :login
    live "/register", AuthLive.Register, :register

    post "/login", SessionController, :login
    post "/register", SessionController, :register
    delete "/logout", SessionController, :logout
  end

  # Other scopes may use custom stacks.
  # scope "/api", NajvaWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard in development
  if Application.compile_env(:najva, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: NajvaWeb.Telemetry
    end
  end
end
