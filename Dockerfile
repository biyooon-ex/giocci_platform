FROM hexpm/elixir:1.19.5-erlang-28.3-ubuntu-noble-20251013

ARG TARGETARCH

ARG ZENOH_VERSION=1.7.2
ARG ZENOH_URL=https://github.com/eclipse-zenoh/zenoh/releases/download/${ZENOH_VERSION}

ENV GIOCCI_ZENOH_HOME=/opt/zenoh-${ZENOH_VERSION}
ENV PATH="${GIOCCI_ZENOH_HOME}:${PATH}"

# WHY: enable to build on arm64/macOS (added same line in apps/giocci*/Dockerfile)
# https://hexdocs.pm/mix/Mix.Tasks.Release.html#module-using-images
# https://github.com/erlang/otp/issues/10355#issuecomment-3510018425
ENV ERL_AFLAGS="+JMsingle true"

EXPOSE 7447/tcp
EXPOSE 7446/udp

RUN case "${TARGETARCH}" in \
      amd64) ZENOH_ARCH="x86_64-unknown-linux-gnu" ;; \
      arm64) ZENOH_ARCH="aarch64-unknown-linux-gnu" ;; \
      *) echo "Unsupported architecture: ${TARGETARCH}" && exit 1 ;; \
    esac \
  && ZENOH_ARCHIVE="zenoh-${ZENOH_VERSION}-${ZENOH_ARCH}-standalone.zip" \
  && apt-get update \
  && apt-get install -y --no-install-recommends curl unzip ca-certificates \
  && mkdir -p "${GIOCCI_ZENOH_HOME}" \
  && curl -fsSL "${ZENOH_URL}/${ZENOH_ARCHIVE}" -o "/tmp/${ZENOH_ARCHIVE}" \
  && unzip "/tmp/${ZENOH_ARCHIVE}" -d "${GIOCCI_ZENOH_HOME}" \
  && rm "/tmp/${ZENOH_ARCHIVE}" \
  && rm -rf /var/lib/apt/lists/*

RUN mix local.hex --force

WORKDIR /app

CMD ["zenohd"]
