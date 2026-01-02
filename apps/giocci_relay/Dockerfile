FROM hexpm/elixir:1.19.4-erlang-28.3-ubuntu-noble-20251013 AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /root
ENV MIX_ENV=prod
ENV LANG=C.UTF-8

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.exs
COPY apps apps
RUN mix deps.get --only prod
RUN mix deps.compile
RUN mix compile
RUN mix release giocci_relay

FROM ubuntu:noble-20251013 AS runner

WORKDIR /root
ENV MIX_ENV=prod
ENV LANG=C.UTF-8

COPY --from=builder /root/_build/prod/rel/giocci_relay giocci_relay

CMD ["/root/giocci_relay/bin/giocci_relay", "start"]
