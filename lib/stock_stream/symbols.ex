defmodule StockStream.Symbols do
  @moduledoc "Single source for symbols"

  def list, do: Application.fetch_env!(:stock_stream, :initial_symbols)
end
