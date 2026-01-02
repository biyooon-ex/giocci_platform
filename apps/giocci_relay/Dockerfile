FROM hexpm/elixir:1.19.4-erlang-28.2-ubuntu-noble-20251013

RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /root

RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV=prod

COPY mix.exs mix.exs
COPY apps apps
RUN mix deps.get --only prod
RUN mix deps.compile
RUN mix compile
RUN mix release giocci_relay

CMD ["/root/_build/prod/rel/giocci_relay/bin/giocci_relay", "start"]
