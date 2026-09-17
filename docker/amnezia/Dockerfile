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
COPY docker/amnezia/init.sh /init.sh

RUN chmod +x /init.sh

HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD sh -c "awg show | grep -q '^interface:'"

ENTRYPOINT ["/usr/bin/dumb-init", "--", "/init.sh"]
