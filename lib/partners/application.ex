defmodule Partners.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PartnersWeb.Telemetry,
      Partners.Repo,
      {DNSCluster, query: Application.get_env(:partners, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Partners.PubSub},
      # Start the PayPal Certificate Cache Agent
      %{
        id: Partners.Services.PaypalCertificateManager,
        start:
          {Agent, :start_link,
           [fn -> %{} end, [name: Partners.Services.PaypalCertificateManager]]}
      },
       PartnersWeb.Registration.RegistrationFormAgent,
      # Start a worker by calling: Partners.Worker.start_link(arg)
      # {Partners.Worker, arg},
      # Start to serve requests, typically the last entry
      PartnersWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Partners.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PartnersWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
