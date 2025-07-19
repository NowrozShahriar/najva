defmodule Najva.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      NajvaWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:najva, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Najva.PubSub},
      # Start a worker by calling: Najva.Worker.start_link(arg)
      # {Najva.Worker, arg},
      # Start the XMPP client
      # Najva.XmppClient,
      # Start to serve requests, typically the last entry
      NajvaWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Najva.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    NajvaWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
