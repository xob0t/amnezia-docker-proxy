FROM golang:1.24.5 AS builder

ARG TARGETARCH
ARG TARGETVARIANT

WORKDIR /src/amneziawg-go

RUN git clone --depth=1 https://github.com/amnezia-vpn/amneziawg-go.git . \
 && go mod download \
 && CGO_ENABLED=0 GOOS=linux GOARCH=${TARGETARCH} GOARM=${TARGETVARIANT#v} \
    go build -ldflags="-s -w" -o /out/amneziawg-go

FROM alpine:3.22

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
 && git clone --depth=1 https://github.com/amnezia-vpn/amneziawg-tools.git /tmp/amneziawg-tools \
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
