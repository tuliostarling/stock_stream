defmodule StockStream.Markets.PriceStreamer do
  @moduledoc """
  Mock api for stock price.

  - one process per stock,
  - ticks once per 2 seconds,
  - broadcasts {:price_update, symbol, price} on pub sub using Markets.topic/1.
  """
  use GenServer

  require Logger

  alias StockStream.Markets
  alias StockStream.Markets.PriceCache

  @type state :: %{symbol: String.t(), price: float(), tick_ms: pos_integer()}

  @spec start_link(String.t()) :: GenServer.on_start()
  def start_link(symbol) when is_binary(symbol), do: start_link({symbol, []})

  @spec start_link({String.t(), keyword()}) :: GenServer.on_start()
  def start_link({symbol, opts}) do
    GenServer.start_link(__MODULE__, {symbol, opts}, name: via(symbol))
  end

  @spec via(String.t()) :: {:via, module(), term()}
  def via(symbol), do: {:via, Registry, {StockStream.Registry, {:streamer, symbol}}}

  @impl true
  @spec init({String.t(), keyword()}) :: {:ok, state()}
  def init({symbol, opts}) do
    interval = Keyword.get(opts, :tick_ms, 2_000)

    price =
      case PriceCache.fetch(symbol) do
        {:ok, price} -> price
        :error -> random_price()
      end

    state = %{symbol: symbol, price: price, tick_ms: interval}
    schedule_tick(interval)
    {:ok, state}
  end

  @impl true
  @spec handle_info(:tick, state()) :: {:noreply, state()}
  def handle_info(:tick, %{price: old_price, tick_ms: tick_ms, symbol: symbol} = state) do
    new_price = jitter(old_price)
    last_pct = Float.round((new_price - old_price) / old_price * 100, 2)

    PriceCache.put(symbol, new_price)

    if Registry.lookup(StockStream.Registry, {:subscriber, symbol}) != [] do
      Logger.info(fn -> "[PUBSUB] #{symbol} → $#{new_price} (#{last_pct}%)" end)
    end

    Phoenix.PubSub.broadcast(
      StockStream.PubSub,
      Markets.topic(symbol),
      {:price_update, symbol, new_price, last_pct}
    )

    schedule_tick(tick_ms)
    {:noreply, %{state | price: new_price}}
  end

  @impl true
  @spec handle_cast(:crash, state()) :: {:stop, :crash_simulated, state()}
  def handle_cast(:crash, state), do: {:stop, :crash_simulated, state}

  @spec schedule_tick(pos_integer()) :: reference()
  defp schedule_tick(ms), do: Process.send_after(self(), :tick, ms)

  @spec random_price() :: float()
  defp random_price, do: :rand.uniform(1_000) / 1

  # Nudge the price randomly by around 1%, then round to cents
  @spec jitter(float()) :: float()
  defp jitter(price), do: Float.round(price * (:rand.uniform() * 0.02 + 0.99), 2)
end
