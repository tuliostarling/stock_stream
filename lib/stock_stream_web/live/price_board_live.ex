defmodule StockStreamWeb.PriceBoardLive do
  use StockStreamWeb, :live_view

  alias StockStream.Markets

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       prices: %{},
       symbols: StockStream.Symbols.list(),
       subscribed: MapSet.new(),
       temporary_assigns: [prices: %{}]
     )}
  end

  @impl true
  def handle_info(:clear_flash, socket), do: {:noreply, clear_flash(socket)}

  @impl true
  def handle_info({:price_update, symbol, price, last_pct}, socket) do
    entry =
      case socket.assigns.prices[symbol] do
        nil ->
          %{
            start: price,
            price: price,
            start_pct: 0.0,
            last_pct: 0.0
          }

        %{start: start_price} = prev ->
          %{
            prev
            | price: price,
              start_pct: Float.round((price - start_price) / start_price * 100, 2),
              last_pct: last_pct
          }
      end

    {:noreply, update(socket, :prices, &Map.put(&1, symbol, entry))}
  end

  @impl true
  def handle_event(
        "toggle_sub",
        %{"symbol" => symbol},
        %{assigns: %{subscribed: set, prices: prices}} = socket
      ) do
    {action, new_set, new_prices} =
      set
      |> MapSet.member?(symbol)
      |> case do
        false ->
          Markets.subscribe(symbol)
          {:subscribed, MapSet.put(set, symbol), prices}

        true ->
          Markets.unsubscribe(symbol)
          {:unsubscribed, MapSet.delete(set, symbol), Map.delete(prices, symbol)}
      end

    {:noreply,
     socket
     |> put_flash(:info, "#{symbol} #{action}")
     |> then(fn socket ->
       Process.send_after(self(), :clear_flash, 5_000)
       socket
     end)
     |> assign(subscribed: new_set, prices: new_prices)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-full mb-3">
      <h3 class="text-xl font-bold text-slate-800">Live Prices</h3>
    </div>

    <div class="shadow-md rounded-lg">
      <table class="w-full text-left table-auto min-w-max">
        <thead>
          <tr>
            <th class="p-4 border-b border-slate-300 bg-slate-50 rounded-lg">
              <p class="block text-sm font-normal leading-none text-slate-500">
                Symbol
              </p>
            </th>
            <th class="p-4 border-b border-slate-300 bg-slate-50">
              <p class="block text-sm font-normal leading-none text-slate-500">
                Start Price
              </p>
            </th>
            <th class="p-4 border-b border-slate-300 bg-slate-50">
              <p class="block text-sm font-normal leading-none text-slate-500">
                From Start (%)
              </p>
            </th>
            <th class="p-4 border-b border-slate-300 bg-slate-50">
              <p class="block text-sm font-normal leading-none text-slate-500">
                Current Price
              </p>
            </th>
            <th class="p-4 border-b border-slate-300 bg-slate-50">
              <p class="block text-sm font-normal leading-none text-slate-500">
                Last Tick (%)
              </p>
            </th>
            <th class="p-4 border-b border-slate-300 bg-slate-50 rounded-lg" />
          </tr>
        </thead>
        <tbody>
          <%= for symbol <- @symbols do %>
            <% entry = @prices[symbol] %>

            <tr
              id={"row-#{symbol}"}
              phx-update="replace"
              class="hover:bg-slate-50 border-b border-slate-200"
            >
              <td class="p-4 py-5 rounded-lg">
                <p class="block font-semibold text-sm text-slate-800">{symbol}</p>
              </td>

              <td class="p-4 py-5">
                <p class="block text-sm text-slate-800">
                  <%= if entry do %>
                    US$ {entry.start}
                  <% else %>
                    <p class="block text-slate-800">
                      <.icon name="hero-minus" class="w-4 h-4" />
                    </p>
                  <% end %>
                </p>
              </td>

              <td class="p-4 py-5">
                <%= if entry do %>
                  <p class={
                  "flex items-center justify-start text-sm " <>
                    cond do
                      entry.start_pct > 0 -> "text-green-600"
                      entry.start_pct < 0 -> "text-red-600"
                      true -> "text-blue-500"
                    end
                  }>
                    <%= cond do %>
                      <% entry.start_pct > 0 -> %>
                        <.icon name="hero-arrow-up" class="mr-1 w-3 h-3" />
                      <% entry.start_pct < 0 -> %>
                        <.icon name="hero-arrow-down" class="mr-1 w-3 h-3" />
                      <% true -> %>
                        <.icon name="hero-minus" class="mr-1 w-3 h-3" />
                    <% end %>
                    {abs(entry.start_pct)}%
                  </p>
                <% else %>
                  <p class="block text-slate-800">
                    <.icon name="hero-minus" class="w-4 h-4" />
                  </p>
                <% end %>
              </td>

              <td class="p-4 py-5">
                <p class="block text-sm text-slate-800">
                  <%= if entry do %>
                    US$ {entry.price}
                  <% else %>
                    <p class="block text-slate-800">
                      <.icon name="hero-minus" class="w-4 h-4" />
                    </p>
                  <% end %>
                </p>
              </td>

              <td class="p-4 py-5">
                <%= if entry do %>
                  <p class={
                  "flex items-center justify-start text-sm " <>
                    cond do
                      entry.last_pct > 0 -> "text-green-600"
                      entry.last_pct < 0 -> "text-red-600"
                      true -> "text-blue-500"
                    end
                  }>
                    <%= cond do %>
                      <% entry.last_pct > 0 -> %>
                        <.icon name="hero-arrow-up" class="mr-1 w-3 h-3" />
                      <% entry.last_pct < 0 -> %>
                        <.icon name="hero-arrow-down" class="mr-1 w-3 h-3" />
                      <% true -> %>
                        <.icon name="hero-minus" class="mr-1 w-3 h-3" />
                    <% end %>
                    {abs(entry.last_pct)}%
                  </p>
                <% else %>
                  <p class="block text-slate-800">
                    <.icon name="hero-minus" class="w-4 h-4" />
                  </p>
                <% end %>
              </td>

              <td class="p-4 py-5 text-right w-36 rounded-lg">
                <button
                  phx-click="toggle_sub"
                  phx-value-symbol={symbol}
                  class={"px-2 py-1 rounded text-sm " <> if MapSet.member?(@subscribed, symbol), do: "bg-red-600 text-white", else: "bg-green-600 text-white"}
                >
                  {if MapSet.member?(@subscribed, symbol), do: "Unsubscribe", else: "Subscribe"}
                </button>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end
end
