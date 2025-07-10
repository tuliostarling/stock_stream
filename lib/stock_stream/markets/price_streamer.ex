defmodule StockStream.Markets.PriceStreamer do
  @moduledoc """
  Mock api for stock price.

  - one process per stock,
  - ticks once per 2 seconds,
  - broadcasts {:price_update, symbol, price} on pub sub using Markets.topic/1.
  """
  use GenServer

  alias StockStream.Markets

  @type state :: %{symbol: String.t(), price: float()}

  @spec start_link(String.t()) :: GenServer.on_start()
  def start_link(symbol), do: GenServer.start_link(__MODULE__, symbol, name: via(symbol))

  @spec via(String.t()) :: {:via, module(), term()}
  def via(symbol), do: {:via, Registry, {StockStream.Registry, {:streamer, symbol}}}

  @impl GenServer
  @spec init(String.t()) :: {:ok, state()}
  def init(symbol) do
    schedule_tick()
    {:ok, %{symbol: symbol, price: random_price()}}
  end

  @impl GenServer
  @spec handle_info(:tick, state()) :: {:noreply, state()}
  def handle_info(:tick, %{price: old_price} = state) do
    new_price = jitter(old_price)
    last_pct = Float.round((new_price - old_price) / old_price * 100, 2)

    Phoenix.PubSub.broadcast(
      StockStream.PubSub,
      Markets.topic(state.symbol),
      {:price_update, state.symbol, new_price, last_pct}
    )

    schedule_tick()
    {:noreply, %{state | price: new_price}}
  end

  @spec schedule_tick() :: reference()
  defp schedule_tick, do: Process.send_after(self(), :tick, 2_000)

  @spec random_price() :: float()
  defp random_price, do: :rand.uniform(1_000) / 1

  # Nudge the price randomly by around 1%, then round to cents
  @spec jitter(float()) :: float()
  defp jitter(price), do: Float.round(price * (:rand.uniform() * 0.02 + 0.99), 2)
end
