FROM hexpm/elixir:1.19.4-erlang-28.3-ubuntu-noble-20251013 AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /root
ENV MIX_ENV=prod
ENV LANG=C.UTF-8

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.exs
COPY mix.lock mix.lock
COPY config config
RUN mix deps.get --only prod
RUN mix deps.compile

COPY lib lib
RUN mix compile
RUN mix release giocci_engine

FROM ubuntu:noble-20251013 AS runner

WORKDIR /root
ENV MIX_ENV=prod
ENV LANG=C.UTF-8

COPY --from=builder /root/_build/prod/rel/giocci_engine giocci_engine

CMD ["/root/giocci_engine/bin/giocci_engine", "start"]
