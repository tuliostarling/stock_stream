defmodule StockStream.Repo do
  use Ecto.Repo,
    otp_app: :stock_stream,
    adapter: Ecto.Adapters.Postgres
end
