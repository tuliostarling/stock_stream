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
       crashing: MapSet.new(),
       symbol_input: "",
       temporary_assigns: [prices: %{}]
     )}
  end

  @impl true
  def handle_info(:clear_flash, socket), do: {:noreply, clear_flash(socket)}

  @impl true
  def handle_info({:recover_symbol, symbol}, %{assigns: %{crashing: crashing}} = socket) do
    {:noreply, assign(socket, :crashing, MapSet.delete(crashing, symbol))}
  end

  @impl true
  def handle_info({:price_update, symbol, price, last_pct}, socket) do
    entry = build_entry(socket.assigns.prices[symbol], price, last_pct)

    socket =
      socket
      |> update(:prices, &Map.put(&1, symbol, entry))
      |> maybe_mark_recovered(symbol)

    {:noreply, socket}
  end

  @impl true
  def handle_event("crash", %{"symbol" => symbol}, socket) do
    Markets.crash(symbol)

    {:noreply,
     socket
     |> update(:crashing, &MapSet.put(&1, symbol))
     |> put_flash(:info, "Stream for #{symbol} crashed (simulated)")
     |> then(fn socket ->
       Process.send_after(self(), :clear_flash, 5_000)
       socket
     end)}
  end

  @impl true
  def handle_event("symbol_input", %{"symbol" => txt}, socket) do
    {:noreply, assign(socket, :symbol_input, txt)}
  end

  @impl true
  def handle_event("add_symbol", %{"symbol" => raw}, socket) do
    symbol = raw |> String.trim() |> String.upcase()

    cond do
      symbol == "" ->
        {:noreply, put_flash(socket, :error, "Symbol cannot be empty")}

      symbol in socket.assigns.symbols ->
        {:noreply, put_flash(socket, :error, "#{symbol} already listed")}

      true ->
        Markets.start_stream(symbol)

        {:noreply,
         socket
         |> update(:symbols, &[symbol | &1])
         |> assign(:symbol_input, "")
         |> put_flash(:info, "#{symbol} added")
         |> then(fn s ->
           Process.send_after(self(), :clear_flash, 5_000)
           s
         end)}
    end
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

  defp build_entry(symbol, price, last_pct) do
    case symbol do
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
  end

  defp maybe_mark_recovered(socket, symbol) do
    if MapSet.member?(socket.assigns.crashing, symbol) do
      socket
      |> update(:crashing, &MapSet.delete(&1, symbol))
      |> put_flash(:info, "Stream for #{symbol} restarted")
      |> then(fn s ->
        Process.send_after(self(), :clear_flash, 5_000)
        s
      end)
    else
      socket
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-full flex justify-between items-center mb-3 mt-1">
      <div>
        <h3 class="text-lg font-semibold text-slate-800">
          Live Prices
        </h3>
        <p class="text-slate-500">
          Add a new symbol and watch it stream.
        </p>
      </div>

      <form
        phx-change="symbol_input"
        phx-submit="add_symbol"
        class="ml-3 w-full max-w-sm min-w-[200px] relative"
      >
        <input
          name="symbol"
          value={@symbol_input}
          placeholder="e.g. SNOW"
          class="bg-white w-full h-10 pr-11 pl-3 py-2 placeholder:text-slate-400
                text-slate-700 text-sm border border-slate-200 rounded
                transition duration-300 ease focus:outline-none
                focus:border-slate-400 hover:border-slate-400 shadow-sm
                focus:shadow-md uppercase"
        />

        <button type="submit" class="absolute right-1 top-1 h-8 w-8 flex items-center justify-center bg-white rounded">
          <.icon name="hero-plus" class="w-4 h-4 text-slate-600" />
        </button>
      </form>
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

              <td class="p-4 py-5 flex justify-evenly items-center text-right rounded-lg">
                <button
                  phx-click="toggle_sub"
                  phx-value-symbol={symbol}
                  disabled={MapSet.member?(@crashing, symbol)}
                  class={
                    "px-2 py-1 rounded text-sm " <>
                    (if MapSet.member?(@subscribed, symbol), do: "bg-red-600 text-white", else: "bg-green-600 text-white") <>
                    (if MapSet.member?(@crashing, symbol), do: " opacity-50 cursor-not-allowed", else: "")
                  }
                >
                  {if MapSet.member?(@subscribed, symbol), do: "Unsubscribe", else: "Subscribe"}
                </button>

                <%= if MapSet.member?(@crashing, symbol) do %>
                  <.icon name="hero-arrow-path" class="animate-spin w-4 h-4 text-slate-500" />
                <% else %>
                  <button
                    phx-click="crash"
                    phx-value-symbol={symbol}
                    class="px-2 py-1 bg-yellow-500 hover:bg-yellow-600 text-white rounded text-sm"
                  >
                    Crash
                  </button>
                <% end %>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end
end
