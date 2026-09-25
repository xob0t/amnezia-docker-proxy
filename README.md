# Amnezia VPN в Docker + SOCKS5 / HTTP proxy

Стек собирает **свой Alpine-образ** с `amneziawg-go` и `amneziawg-tools` (без готового клиентского image) и использует **только локальные конфиги** из папки `config`.

## 1) Получение `amnezia.conf` из клиента Amnezia

Нужен именно готовый `.conf` файл из приложения Amnezia/AmneziaWG.

Примерный путь в клиенте:

1. Открой приложение Amnezia.
2. Выбери нужный сервер/локацию.
3. Открой меню соединения и нажми что-то вроде:
   - `Export config`,
   - `Share`,
   - `Download .conf`,
   - `Save as file`.
4. Сохрани файл на хост в этот проект как:
   - `config/amnezia.conf`

Если клиент предлагает несколько форматов, выбирай формат **AmneziaWG/WireGuard `.conf`**.

## 2) Подготовка проекта

1. Скопируй env:

```bash
cp .env.example .env
```

2. Проверь, что файл есть:

```bash
ls -la config/amnezia.conf
```

## 3) Запуск

Запусти стек:

```bash
docker compose up -d --build
```

Проверка статуса:

```bash
docker compose ps
docker compose logs --tail=100 amnezia
```

## 4) Использование прокси в приложениях

Поддерживаются два протокола, оба выходят через VPN:

| Протокол | host        | port   |
|----------|-------------|--------|
| SOCKS5   | `127.0.0.1` | `1080` |
| HTTP     | `127.0.0.1` | `3128` |

Порты можно сменить в `.env`:

```env
SOCKS_PORT=1080
HTTP_PORT=3128
```

Авторизация настраивается отдельно для каждого протокола:

```env
SOCKS5_USER=socks_user
SOCKS5_PASSWORD=socks_password

HTTP_USER=http_user
HTTP_PASSWORD=http_password
```

Правило простое: если для протокола заполнены и логин, и пароль — auth включена; если поля пустые — auth выключена.

Перезапусти после изменений:

```bash
docker compose up -d --build
```

## 5) Если не подключается

- Убедись, что `config/amnezia.conf` актуален и действительно экспортирован из Amnezia.
- Проверь логи: `docker compose logs --tail=150 amnezia`.
- Если сервер в конфиге заблокирован/мертв, экспортируй другой профиль из клиента.

## Как это работает внутри

- `amnezia` — единственный контейнер: поднимает активный `config/amnezia.conf` в самособранном Alpine-образе, затем запускает `3proxy` с SOCKS5 на `1080` и HTTP на `3128`. Если прокси падает, падает весь контейнер, и Docker перезапускает VPN и прокси вместе.

## Что в проекте

- `docker/amnezia/Dockerfile` — кастомный Alpine-образ с `amneziawg-go` и `amneziawg-tools`.
- `docker/amnezia/init.sh` — запуск активного профиля и прокси.
- `docker/proxy/entrypoint.sh` — генерирует конфиг `3proxy` для SOCKS5 и HTTP и запускает его.

## Deployment notes for this mirror

- The Go builder uses Go 1.25. AmneziaWG source revisions are pinned in the Dockerfile so an upstream update cannot silently change the required compiler.
- `HTTP_PORT` and `SOCKS_PORT` change the host ports. The proxy always listens on container ports 3128 and 1080.
- `PROXY_CONNECTION_TIMEOUT` sets the inactivity timeout for HTTP CONNECT and SOCKS5 tunnels. It defaults to 21600 seconds so multi-hour uploads are not cut off by 3proxy's short defaults.
- Published ports bind to loopback by default. Set `PROXY_BIND_ADDRESS=0.0.0.0` to accept external connections and configure authentication before doing so. Incomplete username/password pairs stop startup.
- The proxy uses IPv4, binds outgoing connections to the VPN interface address, and reads DNS servers from the selected VPN config. Separate HTTP and SOCKS5 credentials are supported.
- The image pins 3proxy 1.0.0 at commit `f6963ea302bd01209dc94f8677c3dba9f3504b4e`. Builds fail if the tag no longer resolves to that commit.
- The runtime binary and config path use the `amnezia-proxy` name, isolating this container from host maintenance jobs that target unrelated `3proxy` processes.
- `CONFIG_DIR` can point to a persistent directory outside the Git checkout. The VPN config is mounted read-only. `ACTIVE_CONFIG_FILE` defaults to `amnezia.conf`.
- For an IPv4-only host/profile that cannot install the supplied IPv6 routes, set `VPN_IPV6=false`. This removes IPv6 entries from `AllowedIPs` in the runtime copy, preserving the source config.
- For Dokploy, set `PROXY_NETWORK_NAME=dokploy-network` and `PROXY_NETWORK_EXTERNAL=true`. Other containers on that network can use `amnezia-proxy:3128` or `amnezia-proxy:1080`. Keep the VPN config outside Dokploy's Git checkout so it survives redeployments.
- The proxy starts only after the VPN interface has its IPv4 address. It runs in the VPN container rather than a `network_mode: service:` sidecar, because a sidecar keeps the old network namespace when the VPN container restarts or the host reboots and then silently stops accepting connections. The healthcheck covers the VPN interface and both proxy ports.

To test a deployed image on its Docker host, run the smoke test as root with Docker, curl, and nsenter available:

```bash
bash tests/proxy-smoke.sh VPN_CONTAINER AMNEZIA_IMAGE /absolute/config/directory amnezia.conf
```

The final argument is the active config filename. The test checks HTTP CONNECT, SOCKS5 DNS resolution, matching VPN egress, and separate credentials in a temporary container that it removes on exit.
