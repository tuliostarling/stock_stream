defmodule StockStream.StreamTestHelper do
  @moduledoc false
  import ExUnit.Assertions

  alias StockStream.Markets

  @registry StockStream.StreamRegistry

  @doc "Starts a stream and calls Mox.allow without subscribing"
  @spec start_stream_with_mock(String.t(), keyword()) :: {:ok, pid()}
  def start_stream_with_mock(symbol, opts \\ [tick_ms: 10]) do
    {:ok, _pid} = Markets.start_stream(symbol, opts)
    [{streamer_pid, _}] = Registry.lookup(@registry, {:streamer, symbol})
    {:ok, streamer_pid}
  end

  @doc "Starts a stream and subscribes the current process to it"
  @spec start_and_subscribe(String.t(), keyword()) :: {:ok, pid()}
  def start_and_subscribe(symbol, opts \\ [tick_ms: 10]) do
    {:ok, _pid} = Markets.start_stream(symbol, opts)

    [{streamer_pid, _}] = Registry.lookup(@registry, {:streamer, symbol})

    :ok = Markets.subscribe(symbol)
    {:ok, streamer_pid}
  end

  @doc "Generates a unique symbol name for each test"
  @spec unique_symbol() :: String.t()
  def unique_symbol, do: "TEST_#{System.unique_integer([:positive])}"

  @doc "Flushes any pending :price_update messages for a given symbol"
  @spec flush_price_updates(String.t()) :: :ok
  def flush_price_updates(symbol) do
    receive do
      {:price_update, ^symbol, _, _} -> flush_price_updates(symbol)
    after
      0 -> :ok
    end
  end

  @doc "Waits until the given pid is fully down by monitoring it"
  @spec wait_for_process_down(pid(), non_neg_integer()) :: :ok
  def wait_for_process_down(pid, timeout \\ 200) do
    ref = Process.monitor(pid)

    receive do
      {:DOWN, ^ref, :process, ^pid, _reason} ->
        :ok
    after
      timeout -> flunk("Process did not go down in time")
    end
  end

  @spec wait_for_stream_restart(String.t(), pid() | nil, non_neg_integer()) :: :ok
  def wait_for_stream_restart(symbol, old_pid \\ nil, retries \\ 20)

  def wait_for_stream_restart(_symbol, _old_pid, 0), do: flunk("Stream was not restarted in time")

  def wait_for_stream_restart(symbol, old_pid, retries) do
    with [{new_pid, _}] <- Registry.lookup(@registry, {:streamer, symbol}),
         true <- is_pid(new_pid),
         true <- Process.alive?(new_pid),
         true <- old_pid == nil or new_pid != old_pid do
      ref = Process.monitor(new_pid)

      receive do
        {:DOWN, ^ref, :process, ^new_pid, _reason} ->
          Process.sleep(50)
          wait_for_stream_restart(symbol, old_pid, retries - 1)
      after
        0 -> :ok
      end
    else
      _ ->
        Process.sleep(100)
        wait_for_stream_restart(symbol, old_pid, retries - 1)
    end
  end
end
