FROM hexpm/elixir:1.19.6-erlang-28.5.0.8-ubuntu-noble-20261024.1

ARG TARGETARCH

ARG ZENOH_VERSION=1.10.2
ARG ZENOH_URL=https://github.com/eclipse-zenoh/zenoh/releases/download/${ZENOH_VERSION}

# Zenoh architecture mappings and SHA256 checksums for Zenoh releases
ARG ZENOH_ARCH_amd64=x86_64-unknown-linux-gnu
ARG ZENOH_SHA256_amd64=319a29fe9a5883103d2f96acc31643435a9453e95d2350f5f2572c56d85092a5
ARG ZENOH_ARCH_arm64=aarch64-unknown-linux-gnu
ARG ZENOH_SHA256_arm64=7852171c442d94b5ab000a358ecc8ecbedefbc257a43669265926ce04802d1d3

ENV GIOCCI_ZENOH_HOME=/opt/zenoh-${ZENOH_VERSION}
ENV PATH="${GIOCCI_ZENOH_HOME}:${PATH}"

# WHY: enable to build on arm64/macOS (added same line in apps/giocci*/Dockerfile)
# https://hexdocs.pm/mix/Mix.Tasks.Release.html#module-using-images
# https://github.com/erlang/otp/issues/10355#issuecomment-3510018425
ENV ERL_AFLAGS="+JMsingle true"

EXPOSE 7447/tcp
EXPOSE 7446/udp

RUN case "${TARGETARCH}" in \
  amd64) ZENOH_ARCH="${ZENOH_ARCH_amd64}"; ZENOH_SHA256="${ZENOH_SHA256_amd64}" ;; \
  arm64) ZENOH_ARCH="${ZENOH_ARCH_arm64}"; ZENOH_SHA256="${ZENOH_SHA256_arm64}" ;; \
  *) echo "Unsupported architecture: ${TARGETARCH}" && exit 1 ;; \
  esac \
  && ZENOH_ARCHIVE="zenoh-${ZENOH_VERSION}-${ZENOH_ARCH}-standalone.zip" \
  && apt-get update \
  && apt-get install -y --no-install-recommends curl unzip ca-certificates \
  && mkdir -p "${GIOCCI_ZENOH_HOME}" \
  && curl -fsSL "${ZENOH_URL}/${ZENOH_ARCHIVE}" -o "/tmp/${ZENOH_ARCHIVE}" \
  && echo "${ZENOH_SHA256}  /tmp/${ZENOH_ARCHIVE}" | sha256sum -c - \
  && unzip "/tmp/${ZENOH_ARCHIVE}" -d "${GIOCCI_ZENOH_HOME}" \
  && rm "/tmp/${ZENOH_ARCHIVE}" \
  && rm -rf /var/lib/apt/lists/*

RUN mix local.hex --force

WORKDIR /app

CMD ["zenohd"]
