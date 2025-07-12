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
    key = {:subscriber, symbol}

    case Registry.lookup(StockStream.SubscriberRegistry, key) do
      [{pid, _} | _] when pid == self() ->
        Logger.info("[SUB] pid #{inspect(pid)} already subscribed to #{symbol}")
        {:error, :already_subscribed}

      _not_subscribed ->
        Registry.register(StockStream.SubscriberRegistry, key, nil)
        PubSub.subscribe(StockStream.PubSub, topic(symbol))
        Logger.info("[SUB] pid #{inspect(self())} subscribed to #{symbol}")
        :ok
    end
  end

  @spec unsubscribe(String.t()) :: :ok
  def unsubscribe(symbol) do
    Logger.info("[UNSUB] pid #{inspect(self())} unsubscribed from #{symbol}")
    Registry.unregister(StockStream.SubscriberRegistry, {:subscriber, symbol})
    PubSub.unsubscribe(StockStream.PubSub, topic(symbol))
  end

  @spec crash(String.t()) :: :ok
  def crash(symbol) do
    Logger.warning("[CRASH] #{symbol} - simulated")
    symbol |> PriceStreamer.via() |> GenServer.cast(:crash)
  end

  @doc "Broadcast helper to be used internally"
  @spec topic(String.t()) :: String.t()
  def topic(symbol), do: "prices:#{symbol}"
end
