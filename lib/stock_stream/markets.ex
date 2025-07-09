defmodule StockStream.Markets do
  @moduledoc "Api for random real-time market prices"

  alias Phoenix.PubSub
  alias StockStream.Markets.{PriceStreamer, Supervisor}

  @spec start_stream(String.t()) :: DynamicSupervisor.on_start_child()
  def start_stream(symbol), do: DynamicSupervisor.start_child(Supervisor, {PriceStreamer, symbol})

  @spec stop_stream(String.t()) :: :ok
  def stop_stream(symbol), do: symbol |> PriceStreamer.via() |> GenServer.stop(:normal)

  @spec subscribe(String.t()) :: :ok | {:error, term()}
  def subscribe(symbol), do: PubSub.subscribe(StockStream.PubSub, topic(symbol))

  @doc "Broadcast helper to be used internally"
  @spec topic(String.t()) :: String.t()
  def topic(symbol), do: "prices:#{symbol}"
end
