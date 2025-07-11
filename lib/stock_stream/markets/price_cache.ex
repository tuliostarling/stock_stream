defmodule StockStream.Markets.PriceCache do
  @moduledoc """
  ETS that keeps the latest price per symbol in memory.

  If a PriceStreamer crashes and is restarted by the supervisor, it
  reads the cached value so prices continue smoothly from the last tick.
  """

  @table :stock_prices

  @spec child_spec(term()) :: Supervisor.child_spec()
  def child_spec(_opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [[]]},
      type: :worker
    }
  end

  @spec start_link(list()) :: {:ok, pid()}
  def start_link(_opts) do
    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    {:ok, self()}
  end

  @spec put(String.t(), float()) :: true
  def put(symbol, price), do: :ets.insert(@table, {symbol, price})

  @spec fetch(String.t()) :: {:ok, float()} | :error
  def fetch(symbol) do
    case :ets.lookup(@table, symbol) do
      [{^symbol, price}] -> {:ok, price}
      [] -> :error
    end
  end
end
