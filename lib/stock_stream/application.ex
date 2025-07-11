defmodule StockStream.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @default_symbols ~w(AAPL MSFT TSLA)

  @common_children [
    StockStreamWeb.Telemetry,
    StockStream.Repo,
    {DNSCluster, query: Application.compile_env(:stock_stream, :dns_cluster_query) || :ignore},
    {Phoenix.PubSub, name: StockStream.PubSub},
    {Finch, name: StockStream.Finch},
    StockStreamWeb.Endpoint
  ]

  @runtime_only_children [
    {Registry, keys: :unique, name: StockStream.Registry},
    StockStream.Markets.Supervisor
  ]

  @impl true
  def start(_type, _args) do
    unless Mix.env() == :prod do
      [".env.dev", ".env.local"]
      |> Enum.map(&Path.expand/1)
      |> Enum.filter(&File.exists?/1)
      |> Dotenv.load()

      Mix.Task.run("loadconfig")
    end

    children = @common_children ++ if(Mix.env() == :test, do: [], else: @runtime_only_children)

    opts = [strategy: :one_for_one, name: StockStream.Supervisor]
    {:ok, sup} = Supervisor.start_link(children, opts)

    unless Mix.env() == :test do
      Enum.each(
        Application.get_env(:stock_stream, :initial_symbols, @default_symbols),
        &StockStream.Markets.start_stream/1
      )
    end

    {:ok, sup}
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    StockStreamWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
