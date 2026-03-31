ARG ELIXIR_VERSION=1.19.5
ARG ERLANG_VERSION=28.3
ARG UBUNTU_VERSION=noble-20251013
FROM hexpm/elixir:${ELIXIR_VERSION}-erlang-${ERLANG_VERSION}-ubuntu-${UBUNTU_VERSION} AS builder

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
COPY apps/giocci_relay/mix.exs apps/giocci_relay/mix.lock apps/giocci_relay/
COPY apps/giocci_relay/config apps/giocci_relay/config

WORKDIR /build/apps/giocci_relay
RUN mix deps.get --only prod
RUN mix deps.compile

# Copy application source
COPY apps/giocci_relay/lib lib/
RUN mix compile
RUN mix release giocci_relay

# Runtime stage
FROM ubuntu:${UBUNTU_VERSION} AS runner

# Create non-root user
RUN groupadd -r giocci_relay && \
  useradd -r -g giocci_relay giocci_relay

WORKDIR /app
USER giocci_relay

ENV MIX_ENV=prod
ENV LANG=C.UTF-8

# Copy release from builder
COPY --from=builder --chown=giocci_relay:giocci_relay /build/apps/giocci_relay/_build/prod/rel/giocci_relay ./

# Use ENTRYPOINT and CMD for flexibility
ENTRYPOINT ["/app/bin/giocci_relay"]
CMD ["start"]
