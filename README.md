# StockStream

This project simulates live stock‑price updates (via an in‑memory “market” process) and shows them on a real‑time price board.

## Features

* **Simulated market feed** – `StockStream.Markets` spawns a GenServer per symbol and periodically broadcasts `{:price_update, …}` events.
* **LiveView** – see prices update in real‑time at [http://localhost:4000](http://localhost:4000).
* **Pub/Sub channel** – consumers can subscribe to symbols and receive pushes.

## Requirements

* **Elixir** `1.18.4`
* **Erlang/OTP** `28`
* **PostgreSQL** `15+`
* **Docker & Docker Compose** *(optional)*

> **.tool-versions** is committed, so `asdf install` will pull the correct elixir & erlang versions.

## Local setup

### Clone & install

```bash
git clone https://github.com/tuliostarling/stock_stream.git
cd stock_stream
asdf install        # installs elixir & erlang listed in .tool-versions
```

### Configure dev and test

```bash
cp config/dev.exs.example   config/dev.exs
cp config/test.exs.example  config/test.exs
```

### Install deps

```bash
mix deps.get
```

Edit `config/dev.exs` (or set env‑vars) to point at your local postgres. The defaults are:

```dotenv
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
SECRET_KEY_BASE=
```

> To gen secret key base you can simply run `mix phx.gen.secret` on your bash and copy the value.

### Env vars

Dotenv is loaded automatically, in **dev** & **test**. Create:

* .env.local - for local development;
* .env.dev   - for docker (picked up by docker-compose).

Both files can coexist safely because of the way dotenv is called in application.ex.

### Setup database & run

```bash
mix ecto.setup
iex -S mix phx.server
```

### Running tests (local)

```bash
mix test
```

## Docker setup

Everything you need is bundled in **Dockerfile** + **docker‑compose.yml**.

1. Copy the example env file and update it with your secrets:

   ```bash
   cp .env.example .env.dev
   ```

   *`.env.dev` is picked up by **docker-compose.yml** via `env_file`.*

2. Build & launch:

   ```bash
   docker compose up --build
   ```

   The app will be available at **<http://localhost:4000>**
   (port 5432 is forwarded too, for convenient psql access).

> Internally the app connects to Postgres via the service hostname **`db`**

### Running tests

```bash
docker compose --profile test run --rm test
```

## Project layout

```text
stock_stream/
├── assets/
├── config/
│   ├── dev.exs.example   # copy to dev.exs
│   ├── test.exs.example  # copy to test.exs
│   └── ...
├── lib/
│   ├── stock_stream/
│   └── stock_stream_web/
├── priv/
│   └── repo/
├── test/
├── .env.example         # copy to .env.local for local run or .env.dev for docker run
├── Dockerfile
├── docker-compose.yml
├── mix.exs
└── README.md
```

## Quality check helper

Run compiler with warnings as errors, credo (strict), check format and dialyzer:

```bash
mix check.quality
```
