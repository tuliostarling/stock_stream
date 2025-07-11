defmodule StockStream.Markets do
  @moduledoc "Api for random real-time market prices"
  require Logger

  alias Phoenix.PubSub
  alias StockStream.Markets.{PriceStreamer, Supervisor}

  @spec start_stream(String.t(), keyword()) :: DynamicSupervisor.on_start_child()
  def start_stream(symbol, opts \\ []) do
    Logger.info("[STREAM] start #{symbol}")
    DynamicSupervisor.start_child(Supervisor, {PriceStreamer, {symbol, opts}})
  end

  @spec stop_stream(String.t()) :: :ok
  def stop_stream(symbol) do
    Logger.info("[STREAM] stop #{symbol}")
    symbol |> PriceStreamer.via() |> GenServer.stop(:normal)
  end

  @spec subscribe(String.t()) :: :ok | {:error, :already_subscribed}
  def subscribe(symbol) do
    case Registry.register(StockStream.Registry, {:subscriber, symbol}, nil) do
      {:ok, _} ->
        Logger.info("[SUB] pid #{inspect(self())} subscribed to #{symbol}")
        PubSub.subscribe(StockStream.PubSub, topic(symbol))
        :ok

      {:error, {:already_registered, _}} ->
        Logger.info("[SUB] already subscribed to #{symbol}")
        {:error, :already_subscribed}
    end
  end

  @spec unsubscribe(String.t()) :: :ok
  def unsubscribe(symbol) do
    Logger.info("[UNSUB] pid #{inspect(self())} unsubscribed from #{symbol}")
    Registry.unregister(StockStream.Registry, {:subscriber, symbol})
    PubSub.unsubscribe(StockStream.PubSub, topic(symbol))
  end

  @doc "Broadcast helper to be used internally"
  @spec topic(String.t()) :: String.t()
  def topic(symbol), do: "prices:#{symbol}"
end
