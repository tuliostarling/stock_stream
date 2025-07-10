defmodule StockStream.MarketsTest do
  use StockStream.StockStreamCase, async: true

  import StockStream.StreamTestHelper
  alias StockStream.Markets

  @default_timeout 60

  describe "Markets.subscribe/1 and broadcast" do
    test "receives price updates after subscribing" do
      symbol = unique_symbol()
      {:ok, _pid} = start_and_subscribe(symbol)

      assert_receive {:price_update, ^symbol, price, pct}, @default_timeout
      assert is_float(price)
      assert is_float(pct)
    end

    test "multiple subscribers receive updates for the same symbol" do
      symbol = unique_symbol()
      {:ok, _pid} = start_stream_with_mock(symbol)

      for _ <- 1..3 do
        spawn(fn ->
          Markets.subscribe(symbol)

          receive do
            {:price_update, ^symbol, _price, _pct} -> exit(:ok)
          after
            300 -> exit(:timeout)
          end
        end)
      end

      Process.sleep(@default_timeout)
    end

    test "subscriber only receives updates for the subscribed symbol" do
      symbol1 = unique_symbol()
      symbol2 = unique_symbol()

      {:ok, _pid1} = start_stream_with_mock(symbol1)
      {:ok, _pid2} = start_stream_with_mock(symbol2)

      :ok = Markets.subscribe(symbol1)

      refute_receive {:price_update, ^symbol2, _, _}, @default_timeout
    end

    test "subscribing multiple times returns an error and does not duplicate updates" do
      symbol = unique_symbol()
      {:ok, _pid} = start_stream_with_mock(symbol)

      flush_price_updates(symbol)

      assert :ok = Markets.subscribe(symbol)
      assert {:error, :already_subscribed} = Markets.subscribe(symbol)

      assert_receive {:price_update, ^symbol, _, _}, @default_timeout
      refute_receive {:price_update, ^symbol, _, _}, 5
    end

    test "subscriber joining late still receives future updates" do
      symbol = unique_symbol()
      {:ok, _pid} = start_stream_with_mock(symbol)

      Process.sleep(20)
      :ok = Markets.subscribe(symbol)

      assert_receive {:price_update, ^symbol, _, _}, @default_timeout
    end

    test "unsubscribed process does not receive updates" do
      symbol = unique_symbol()
      {:ok, _pid} = start_stream_with_mock(symbol)

      :ok = Markets.subscribe(symbol)
      :ok = Markets.unsubscribe(symbol)

      refute_receive {:price_update, ^symbol, _, _}, @default_timeout * 2
    end

    test "unsubscribing without subscribing doesn't raise" do
      symbol = unique_symbol()
      {:ok, _pid} = start_stream_with_mock(symbol)

      assert :ok = Markets.unsubscribe(symbol)
    end

    test "no messages are received after stopping stream and waiting for termination" do
      symbol = unique_symbol()
      {:ok, pid} = start_stream_with_mock(symbol)

      :ok = Markets.stop_stream(symbol)
      wait_for_process_down(pid)
      flush_price_updates(symbol)
      :ok = Markets.unsubscribe(symbol)

      refute_receive {:price_update, ^symbol, _, _}, @default_timeout
    end
  end

  describe "crash and restart" do
    @tag :capture_log
    test "streamer crashes and is restarted by supervisor" do
      symbol = unique_symbol()
      {:ok, pid} = start_and_subscribe(symbol)

      GenServer.stop(pid, :shutdown)
      wait_for_process_down(pid)
      wait_for_stream_restart(symbol, pid)
      flush_price_updates(symbol)

      assert_receive {:price_update, ^symbol, _, _}, @default_timeout
    end

    @tag :capture_log
    test "crashing one stream does not affect other running streams" do
      symbol1 = unique_symbol()
      symbol2 = unique_symbol()

      {:ok, pid1} = start_and_subscribe(symbol1)
      {:ok, _pid2} = start_and_subscribe(symbol2)

      GenServer.stop(pid1, :shutdown)
      wait_for_process_down(pid1)
      wait_for_stream_restart(symbol1, pid1)

      assert_receive {:price_update, ^symbol2, _, _}, @default_timeout
    end

    @tag :capture_log
    test "subscribers continue receiving after restart without re-subscribing" do
      symbol = unique_symbol()
      {:ok, pid} = start_and_subscribe(symbol)

      assert_receive {:price_update, ^symbol, _, _}, @default_timeout

      GenServer.stop(pid, :shutdown)
      wait_for_process_down(pid)
      wait_for_stream_restart(symbol, pid)

      assert_receive {:price_update, ^symbol, _, _}, @default_timeout * 2
    end
  end
end
