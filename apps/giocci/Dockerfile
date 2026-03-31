FROM hexpm/elixir:1.19.5-erlang-28.3-ubuntu-noble-20251013 AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /build

ENV MIX_ENV=prod
ENV LANG=C.UTF-8

ENV ERL_AFLAGS="+JMsingle true"

RUN mix local.hex --force && mix local.rebar --force

# Copy VERSIONS to the repo-root equivalent so mix.exs can find it via ../../VERSIONS
COPY VERSIONS ./
COPY apps/giocci/mix.exs apps/giocci/mix.lock apps/giocci/
COPY apps/giocci/config apps/giocci/config

WORKDIR /build/apps/giocci
RUN mix deps.get --only prod
RUN mix deps.compile

# Copy application source
COPY apps/giocci/lib lib/
RUN mix compile
RUN mix release giocci

# Runtime stage
FROM ubuntu:noble-20251013 AS runner

# Create non-root user
RUN groupadd -r giocci && \
  useradd -r -g giocci giocci

WORKDIR /app
USER giocci

ENV MIX_ENV=prod
ENV LANG=C.UTF-8

# Copy release from builder
COPY --from=builder --chown=giocci:giocci /build/apps/giocci/_build/prod/rel/giocci ./

# Use ENTRYPOINT and CMD for flexibility
ENTRYPOINT ["/app/bin/giocci"]
CMD ["start_iex"]
