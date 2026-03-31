FROM hexpm/elixir:1.19.5-erlang-28.3-ubuntu-noble-20251013 AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

ENV MIX_ENV=prod
ENV LANG=C.UTF-8

ENV ERL_AFLAGS="+JMsingle true"

RUN mix local.hex --force && mix local.rebar --force

# Copy VERSIONS so mix.exs can read the project version
COPY VERSIONS /VERSIONS

# Copy dependency files first for better caching
COPY apps/giocci_engine/mix.exs apps/giocci_engine/mix.lock ./
COPY apps/giocci_engine/config ./config
RUN mix deps.get --only prod
RUN mix deps.compile

# Copy application source
COPY apps/giocci_engine/lib ./lib
RUN mix compile
RUN mix release giocci_engine

# Runtime stage
FROM ubuntu:noble-20251013 AS runner

# Create non-root user
RUN groupadd -r giocci_engine && \
  useradd -r -g giocci_engine giocci_engine

WORKDIR /app
USER giocci_engine

ENV MIX_ENV=prod
ENV LANG=C.UTF-8

# Copy release from builder
COPY --from=builder --chown=giocci_engine:giocci_engine /app/_build/prod/rel/giocci_engine ./

# Use ENTRYPOINT and CMD for flexibility
ENTRYPOINT ["/app/bin/giocci_engine"]
CMD ["start"]
