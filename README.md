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
docker compose logs --tail=100 amnezia proxy
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

- `amnezia` — запускает только активный `config/amnezia.conf` в самособранном Alpine-образе.
- `proxy` — поднимает SOCKS5 на `1080` и HTTP на `3128` через `3proxy`; работает в сетевом namespace VPN-контейнера.

## Что в проекте

- `docker/amnezia/Dockerfile` — кастомный Alpine-образ с `amneziawg-go` и `amneziawg-tools`.
- `docker/amnezia/init.sh` — запуск активного профиля.
- `docker/proxy/Dockerfile` + `entrypoint.sh` — образ с `3proxy`, обслуживающий SOCKS5 и HTTP.