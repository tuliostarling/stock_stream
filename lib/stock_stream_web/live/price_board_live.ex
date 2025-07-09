defmodule StockStreamWeb.PriceBoardLive do
  use StockStreamWeb, :live_view
  alias StockStream.Markets

  @symbols ~w(AAPL MSFT GOOG TSLA)

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Enum.each(@symbols, &Markets.subscribe/1)
    end

    {:ok, assign(socket, prices: %{}, symbols: @symbols)}
  end

  @impl true
  def handle_info({:price_update, symbol, price}, socket) do
    {:noreply, update(socket, :prices, &Map.put(&1, symbol, price))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-md mt-10">
      <h2 class="text-2xl font-bold mb-4">📈 Live Prices</h2>

      <table class="w-full border">
        <thead>
          <tr>
            <th class="p-2 text-left">Symbol</th>
            <th class="p-2 text-right">Price</th>
          </tr>
        </thead>

        <tbody>
          <%= for symbol <- @symbols do %>
            <tr>
              <td class="p-2 font-mono">{symbol}</td>
              <td class="p-2 text-right">{@prices[symbol] || "—"}</td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end
end
