defmodule StockStream.StockStreamCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  using do
    quote do
      import StockStream.StreamTestHelper
    end
  end

  setup_all do
    start_supervised!({Registry, keys: :unique, name: StockStream.Registry})

    start_supervised!({
      DynamicSupervisor,
      strategy: :one_for_one,
      name: StockStream.Markets.Supervisor,
      max_restarts: 20,
      max_seconds: 5
    })

    :ok
  end
end
