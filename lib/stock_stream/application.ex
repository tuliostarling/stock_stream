defmodule StockStream.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @default_symbols ~w(AAPL MSFT TSLA)

  @impl true
  def start(_type, _args) do
    children = [
      StockStreamWeb.Telemetry,
      StockStream.Repo,
      {DNSCluster, query: Application.get_env(:stock_stream, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: StockStream.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: StockStream.Finch},
      # Start a worker by calling: StockStream.Worker.start_link(arg)
      # {StockStream.Worker, arg},
      # Start to serve requests, typically the last entry
      StockStreamWeb.Endpoint,
      {Registry, keys: :unique, name: StockStream.Registry},
      StockStream.Markets.Supervisor
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: StockStream.Supervisor]
    {:ok, pid} = Supervisor.start_link(children, opts)

    Enum.each(
      Application.get_env(:stock_stream, :initial_symbols, @default_symbols),
      &StockStream.Markets.start_stream/1
    )

    {:ok, pid}
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    StockStreamWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
