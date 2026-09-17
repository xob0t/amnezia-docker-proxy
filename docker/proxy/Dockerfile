FROM alpine:3.19 AS build
RUN apk add --no-cache build-base git linux-headers
ARG THREEPROXY_VERSION=1.0.0
ARG THREEPROXY_SHA=f6963ea302bd01209dc94f8677c3dba9f3504b4e
RUN git clone --branch "$THREEPROXY_VERSION" --depth 1 \
      https://github.com/3proxy/3proxy.git /src && \
    test "$(git -C /src rev-parse HEAD)" = "$THREEPROXY_SHA"
WORKDIR /src
RUN make -f Makefile.Linux

FROM alpine:3.19
RUN apk add --no-cache iproute2
COPY --from=build /src/bin/3proxy /usr/local/bin/amnezia-proxy
COPY docker/proxy/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
LABEL org.opencontainers.image.version="3proxy-1.0.0" \
      org.opencontainers.image.revision="f6963ea302bd01209dc94f8677c3dba9f3504b4e"
ENTRYPOINT ["/entrypoint.sh"]
