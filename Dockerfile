FROM hexpm/elixir:1.19.4-erlang-28.3-ubuntu-noble-20251013

ARG ZENOH_VERSION=1.7.1
ARG ZENOH_ARCHIVE=zenoh-${ZENOH_VERSION}-x86_64-unknown-linux-gnu-standalone.zip
ARG ZENOH_URL=https://github.com/eclipse-zenoh/zenoh/releases/download/${ZENOH_VERSION}/${ZENOH_ARCHIVE}

ENV ZENOH_HOME=/opt/zenoh-${ZENOH_VERSION}-x86_64-unknown-linux-gnu-standalone
ENV PATH="${ZENOH_HOME}:${PATH}"

EXPOSE 7447/tcp
EXPOSE 7446/udp

RUN apt-get update \
  && apt-get install -y --no-install-recommends curl unzip ca-certificates \
  && update-ca-certificates \
  && mkdir -p "${ZENOH_HOME}" \
  && curl -fsSL "${ZENOH_URL}" -o "/tmp/${ZENOH_ARCHIVE}" \
  && unzip "/tmp/${ZENOH_ARCHIVE}" -d "${ZENOH_HOME}" \
  && rm "/tmp/${ZENOH_ARCHIVE}" \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

RUN mix local.hex --force

CMD ["zenohd"]
