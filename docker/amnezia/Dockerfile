FROM golang:1.25-bookworm AS builder

ARG TARGETARCH
ARG TARGETVARIANT
ARG AMNEZIAWG_GO_REF=b5928efb6ca19f0153958460c3d141f04abc5c2e

WORKDIR /src/amneziawg-go

RUN git init . \
 && git remote add origin https://github.com/amnezia-vpn/amneziawg-go.git \
 && git fetch --depth=1 origin "${AMNEZIAWG_GO_REF}" \
 && git checkout --detach FETCH_HEAD \
 && go mod download \
 && CGO_ENABLED=0 GOOS=linux GOARCH=${TARGETARCH} GOARM=${TARGETVARIANT#v} \
    go build -ldflags="-s -w" -o /out/amneziawg-go

FROM alpine:3.19 AS proxy-builder
RUN apk add --no-cache build-base git linux-headers
ARG THREEPROXY_VERSION=1.0.0
ARG THREEPROXY_SHA=f6963ea302bd01209dc94f8677c3dba9f3504b4e
RUN git clone --branch "$THREEPROXY_VERSION" --depth 1 \
      https://github.com/3proxy/3proxy.git /src && \
    test "$(git -C /src rev-parse HEAD)" = "$THREEPROXY_SHA"
WORKDIR /src
RUN make -f Makefile.Linux

FROM alpine:3.22
ARG AMNEZIAWG_TOOLS_REF=ee0f0a9aa34ff0a0da4b3433b9512781cfe02843

RUN apk --no-cache add \
    bash \
    iproute2 \
    iptables \
    ip6tables \
    openresolv \
    dumb-init \
    linux-headers \
    build-base \
    git \
 && git init /tmp/amneziawg-tools \
 && git -C /tmp/amneziawg-tools remote add origin https://github.com/amnezia-vpn/amneziawg-tools.git \
 && git -C /tmp/amneziawg-tools fetch --depth=1 origin "${AMNEZIAWG_TOOLS_REF}" \
 && git -C /tmp/amneziawg-tools checkout --detach FETCH_HEAD \
 && make -C /tmp/amneziawg-tools/src \
 && make -C /tmp/amneziawg-tools/src install \
 && ln -s /usr/local/bin/awg /usr/bin/wg \
 && ln -s /usr/local/bin/awg-quick /usr/bin/wg-quick \
 && rm -rf /tmp/amneziawg-tools \
 && apk del build-base git

COPY --from=builder /out/amneziawg-go /usr/bin/amneziawg-go
COPY --from=proxy-builder /src/bin/3proxy /usr/local/bin/amnezia-proxy
COPY docker/amnezia/init.sh /init.sh
COPY docker/proxy/entrypoint.sh /proxy-entrypoint.sh

RUN chmod +x /init.sh /proxy-entrypoint.sh

LABEL org.opencontainers.image.version="3proxy-1.0.0" \
      org.opencontainers.image.revision="f6963ea302bd01209dc94f8677c3dba9f3504b4e"

HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD sh -c "awg show | grep -q '^interface:'"

ENTRYPOINT ["/usr/bin/dumb-init", "--", "/init.sh"]
