FROM hexpm/elixir:1.18.4-erlang-28.0.1-ubuntu-jammy-20250619

RUN apt-get update -y && \
  apt-get install -y --no-install-recommends \
  git build-essential inotify-tools postgresql-client && \
  rm -rf /var/lib/apt/lists/*

ENV MIX_ENV=dev PHX_SERVER=true
WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
COPY config ./config
RUN mix deps.get && mix deps.compile

COPY . .

RUN mix compile

CMD ["iex", "-S", "mix", "phx.server"]
