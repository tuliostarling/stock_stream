defmodule StockStream.Markets do
  @moduledoc "Api for random real-time market prices"

  alias Phoenix.PubSub
  alias StockStream.Markets.{PriceStreamer, Supervisor}

  @spec start_stream(String.t(), keyword()) :: DynamicSupervisor.on_start_child()
  def start_stream(symbol, opts \\ []) do
    DynamicSupervisor.start_child(Supervisor, {PriceStreamer, {symbol, opts}})
  end

  @spec stop_stream(String.t()) :: :ok
  def stop_stream(symbol), do: symbol |> PriceStreamer.via() |> GenServer.stop(:normal)

  @spec subscribe(String.t()) :: :ok | {:error, :already_subscribed}
  def subscribe(symbol) do
    case Registry.register(StockStream.Registry, {:subscriber, symbol}, nil) do
      {:ok, _} ->
        PubSub.subscribe(StockStream.PubSub, topic(symbol))
        :ok

      {:error, {:already_registered, _}} ->
        {:error, :already_subscribed}
    end
  end

  @spec unsubscribe(String.t()) :: :ok
  def unsubscribe(symbol) do
    Registry.unregister(StockStream.Registry, {:subscriber, symbol})
    PubSub.unsubscribe(StockStream.PubSub, topic(symbol))
  end

  @doc "Broadcast helper to be used internally"
  @spec topic(String.t()) :: String.t()
  def topic(symbol), do: "prices:#{symbol}"
end
