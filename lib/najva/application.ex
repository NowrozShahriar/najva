defmodule Najva.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      NajvaWeb.Telemetry,
      Najva.Repo,
      {DNSCluster, query: Application.get_env(:najva, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Najva.PubSub},
      # Start a worker by calling: Najva.Worker.start_link(arg)
      # {Najva.Worker, arg},
      # Start clustered process management
      {Horde.Registry, keys: :unique, name: Najva.UserSessionRegistry, members: :auto},
      {Horde.DynamicSupervisor,
       strategy: :one_for_one, name: Najva.UserSessionSupervisor, members: :auto},
      # Initialize Mnesia chat tables
      {Task, &Najva.Chat.ConversationBuffer.init/0}
    ]

    # Load IP Databases (optional)
    locus_dbs = [
      location: "data/location.mmdb",
      asn: "data/asn.mmdb"
    ]

    locus_specs =
      for {id, rel_path} <- locus_dbs,
          full_path = Path.join(:code.priv_dir(:najva), rel_path),
          File.exists?(full_path),
          do: :locus.loader_child_spec(id, full_path)

    children = children ++ locus_specs ++ [NajvaWeb.Endpoint]

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
