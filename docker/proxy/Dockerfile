FROM alpine:3.19 AS build
RUN apk add --no-cache build-base git linux-headers
RUN git clone --depth 1 https://github.com/3proxy/3proxy.git /src
WORKDIR /src
RUN make -f Makefile.Linux

FROM alpine:3.19
COPY --from=build /src/bin/3proxy /usr/local/bin/3proxy
COPY docker/proxy/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
