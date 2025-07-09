defmodule StockStream.Markets.Supervisor do
  @moduledoc false
  use DynamicSupervisor

  def start_link(_), do: DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  def init(:ok), do: DynamicSupervisor.init(strategy: :one_for_one)
end
