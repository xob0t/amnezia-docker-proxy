# Amnezia VPN в Docker + SOCKS5 proxy

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

- host: `127.0.0.1`
- port: `1080`
- type: `SOCKS5`
- auth: выключена по умолчанию (`REQUIRE_AUTH=false`)

Если нужна авторизация, в `.env` выстави:

```env
REQUIRE_AUTH=true
PROXY_USER=your_user
PROXY_PASSWORD=your_password
```

и перезапусти:

```bash
docker compose up -d
```

## 5) Если не подключается

- Убедись, что `config/amnezia.conf` актуален и действительно экспортирован из Amnezia.
- Проверь логи: `docker compose logs --tail=150 amnezia`.
- Если сервер в конфиге заблокирован/мертв, экспортируй другой профиль из клиента.

## Как это работает внутри

- `amnezia` — запускает только активный `config/amnezia.conf` в самособранном Alpine-образе.
- `proxy` — поднимает SOCKS5 на `1080` и работает в сетевом namespace VPN-контейнера.

## Что в проекте

- `docker/amnezia/Dockerfile` — кастомный Alpine-образ с `amneziawg-go` и `amneziawg-tools`.
- `docker/amnezia/init.sh` — запуск активного профиля.