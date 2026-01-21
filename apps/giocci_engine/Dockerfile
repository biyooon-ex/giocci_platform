FROM hexpm/elixir:1.19.5-erlang-28.3-ubuntu-noble-20251013 AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

ENV MIX_ENV=prod
ENV LANG=C.UTF-8

RUN mix local.hex --force && mix local.rebar --force

# Copy dependency files first for better caching
COPY mix.exs mix.lock ./
COPY config ./config
RUN mix deps.get --only prod
RUN mix deps.compile

# Copy application source
COPY lib ./lib
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
