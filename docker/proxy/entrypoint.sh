#!/bin/sh
set -e

CONFIG="/etc/3proxy/3proxy.cfg"
mkdir -p /etc/3proxy
umask 077

ACTIVE_CONFIG_FILE="${ACTIVE_CONFIG_FILE:-amnezia.conf}"
VPN_INTERFACE="${ACTIVE_CONFIG_FILE%.conf}"
VPN_ADDRESS=$(ip -4 -o addr show dev "$VPN_INTERFACE" | awk '{split($4, a, "/"); print a[1]; exit}')
if [ -z "$VPN_ADDRESS" ]; then
    echo "No IPv4 address on VPN interface $VPN_INTERFACE" >&2
    exit 1
fi

is_true() {
    case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
        1|true|yes|on) return 0 ;;
        *) return 1 ;;
    esac
}

SOCKS5_USER="${SOCKS5_USER:-${PROXY_USER:-}}"
SOCKS5_PASSWORD="${SOCKS5_PASSWORD:-${PROXY_PASSWORD:-}}"
HTTP_USER="${HTTP_USER:-${PROXY_USER:-}}"
HTTP_PASSWORD="${HTTP_PASSWORD:-${PROXY_PASSWORD:-}}"

SOCKS5_AUTH_ENABLED=false
HTTP_AUTH_ENABLED=false

if [ -n "$SOCKS5_USER" ] && [ -n "$SOCKS5_PASSWORD" ]; then
    SOCKS5_AUTH_ENABLED=true
elif [ -n "$SOCKS5_USER" ] || [ -n "$SOCKS5_PASSWORD" ]; then
    echo "Both SOCKS5_USER and SOCKS5_PASSWORD must be set" >&2
    exit 1
fi

if [ -n "$HTTP_USER" ] && [ -n "$HTTP_PASSWORD" ]; then
    HTTP_AUTH_ENABLED=true
elif [ -n "$HTTP_USER" ] || [ -n "$HTTP_PASSWORD" ]; then
    echo "Both HTTP_USER and HTTP_PASSWORD must be set" >&2
    exit 1
fi

if is_true "$SOCKS5_AUTH_ENABLED" && is_true "$HTTP_AUTH_ENABLED" && [ "$SOCKS5_USER" = "$HTTP_USER" ] && [ "$SOCKS5_PASSWORD" != "$HTTP_PASSWORD" ]; then
    echo "HTTP and SOCKS5 use the same username with different passwords, which is not supported by 3proxy"
    exit 1
fi

cat > "$CONFIG" << 'CONF'
nscache 65536
log /dev/stdout
logformat "- +_L%t.%.  %N.%p %E %U %C:%c %R:%r %O %I %h %T"
CONF

# The proxy shares the VPN network namespace, but not its /etc/resolv.conf.
awk -F= '/^[[:space:]]*DNS[[:space:]]*=/ {
    count = split($2, servers, /[ ,\t\r]+/)
    for (i = 1; i <= count; i++)
        if (servers[i] ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/)
            print "nserver " servers[i]
}' "/config/$ACTIVE_CONFIG_FILE" >> "$CONFIG"

USERS=""
if is_true "$SOCKS5_AUTH_ENABLED"; then
    USERS="${SOCKS5_USER}:CL:${SOCKS5_PASSWORD}"
fi

if is_true "$HTTP_AUTH_ENABLED"; then
    if ! is_true "$SOCKS5_AUTH_ENABLED" || [ "$HTTP_USER" != "$SOCKS5_USER" ] || [ "$HTTP_PASSWORD" != "$SOCKS5_PASSWORD" ]; then
        if [ -n "$USERS" ]; then
            USERS="${USERS} ${HTTP_USER}:CL:${HTTP_PASSWORD}"
        else
            USERS="${HTTP_USER}:CL:${HTTP_PASSWORD}"
        fi
    fi
fi

if [ -n "$USERS" ]; then
    echo "users ${USERS}" >> "$CONFIG"
fi

if is_true "$HTTP_AUTH_ENABLED"; then
    echo "auth strong" >> "$CONFIG"
    echo "allow ${HTTP_USER}" >> "$CONFIG"
else
    echo "auth none" >> "$CONFIG"
    echo "allow *" >> "$CONFIG"
fi
echo "proxy -4 -p${HTTP_PORT:-3128} -i0.0.0.0 -e${VPN_ADDRESS}" >> "$CONFIG"
echo "flush" >> "$CONFIG"

if is_true "$SOCKS5_AUTH_ENABLED"; then
    echo "auth strong" >> "$CONFIG"
    echo "allow ${SOCKS5_USER}" >> "$CONFIG"
else
    echo "auth none" >> "$CONFIG"
    echo "allow *" >> "$CONFIG"
fi
echo "socks -4 -p${SOCKS5_PORT:-1080} -i0.0.0.0 -e${VPN_ADDRESS}" >> "$CONFIG"

exec 3proxy "$CONFIG"
