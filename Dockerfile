FROM hexpm/elixir:1.19.5-erlang-28.3-ubuntu-noble-20260410

ARG TARGETARCH

ARG ZENOH_VERSION=1.9.0
ARG ZENOH_URL=https://github.com/eclipse-zenoh/zenoh/releases/download/${ZENOH_VERSION}

# Zenoh architecture mappings and SHA256 checksums for Zenoh releases
ARG ZENOH_ARCH_amd64=x86_64-unknown-linux-gnu
ARG ZENOH_SHA256_amd64=f18081184b089e79e605f2c0cb3f7790fbf101ae94942988f716e19e1810a46e
ARG ZENOH_ARCH_arm64=aarch64-unknown-linux-gnu
ARG ZENOH_SHA256_arm64=34e24153dcf69e18f407eb1d2921226a273960cfaa03cefceb452d16434341e7

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
