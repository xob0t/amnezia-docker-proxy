#!/usr/bin/env bash
# Run on the Docker host against an existing VPN container and its config directory.
set -euo pipefail
vpn_container=${1:?VPN container required}
image=${2:?Proxy image required}
config_dir=${3:?Absolute VPN config directory required}
name="amnezia-proxy-smoke-$$"
cleanup() { docker rm -f "$name" >/dev/null 2>&1 || true; }
trap cleanup EXIT

address=$(docker inspect "$vpn_container" --format '{{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}')
address=${address%% *}
docker run --rm -d --name "$name" --network "container:$vpn_container" \
  -v "$config_dir:/config:ro" \
  -e HTTP_PORT=14128 -e SOCKS5_PORT=12080 \
  -e HTTP_USER=httpcheck -e HTTP_PASSWORD=test-http \
  -e SOCKS5_USER=sockscheck -e SOCKS5_PASSWORD=test-socks \
  "$image" >/dev/null

http="http://$address:14128"
socks="socks5h://$address:12080"
for attempt in {1..20}; do
  status=$(curl --noproxy '' -s -o /dev/null -w '%{http_code}' --max-time 2 \
    --proxy "$http" http://example.com || true)
  [[ "$status" == 407 ]] && break
  sleep 1
done
[[ "$status" == 407 ]]
status=$(curl --noproxy '' -s -o /dev/null -w '%{http_code}' --max-time 5 \
  --proxy "$http" --proxy-user httpcheck:wrong http://example.com)
[[ "$status" == 407 ]]

http_ip=$(curl --noproxy '' -fsS --max-time 30 --proxy "$http" \
  --proxy-user httpcheck:test-http https://api.ipify.org)
socks_ip=$(curl --noproxy '' -fsS --max-time 30 --proxy "$socks" \
  --proxy-user sockscheck:test-socks https://api.ipify.org)
[[ "$http_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
[[ "$http_ip" == "$socks_ip" ]]
if curl --noproxy '' -fsS --max-time 5 --proxy "$socks" \
  --proxy-user sockscheck:wrong https://api.ipify.org >/dev/null 2>&1; then
  echo 'SOCKS5 accepted an incorrect password' >&2
  exit 1
fi
cleanup

if docker run --rm --network "container:$vpn_container" \
  -v "$config_dir:/config:ro" -e HTTP_USER=incomplete "$image" >/dev/null 2>&1; then
  echo 'Proxy accepted incomplete credentials' >&2
  exit 1
fi
printf 'PASS: HTTP CONNECT and SOCKS5 DNS/egress (%s), separate credentials, rejected incorrect/missing passwords\n' "$http_ip"
