# Деплой Telegram WEB Proxy (tproxy-server)

Кратко: **WEB Proxy** — новый тип прокси в Telegram Desktop (≥ 7.1.1). Клиент
передаёт MTProxy-трафик через WebView обычным HTTPS к вашему домену. На сервере
релей разбирает поток и отдаёт его локальному MTProxy. Снаружи — обычный сайт.

Это **не** `tg-ws-proxy`. Upstream:
[telegramdesktop/tproxy-server](https://github.com/telegramdesktop/tproxy-server).

## Рекомендуемый способ: Docker (полная автоматизация)

С вашего компьютера одной командой (на VPS нужен **только Docker**):

```bash
./scripts/list-sites.sh

./scripts/install-docker.sh \
  --ssh user@203.0.113.10 \
  --hostname proxy.example.com \
  --email you@example.com \
  --site craft-roastery
```

Скрипт сам:
- сгенерирует секрет;
- соберёт выбранный камуфляжный сайт в `runtime/site/`;
- зальёт проект на VPS в `/opt/tg-web-proxy`;
- соберёт образ и поднимет `docker compose`.

### Что должно быть на VPS (согласуйте один раз)

На хосте **не** ставятся Go, Caddy, MTProxy и systemd-юниты — всё внутри
контейнера. На машине нужно только:

| Требование | Зачем |
|---|---|
| **Docker Engine + Compose plugin** | запуск стека |
| **TCP 80 и 443** снаружи | ACME + HTTPS |
| **DNS A** `proxy.example.com → IP` | сертификат и hostname (без CDN) |
| **x86_64 Linux** | официальный MTProxy |

Установка Docker на VPS (если ещё нет — выполняете **вы** на сервере):

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker "$USER"
```

После этого повторите `install-docker.sh`.

Локальный режим (если уже на VPS):

```bash
./scripts/install-docker.sh --local \
  --hostname proxy.example.com \
  --email you@example.com \
  --site atlas-books
```

Проверка:

```bash
curl --fail https://proxy.example.com/
ssh user@SERVER 'cd /opt/tg-web-proxy && docker compose ps && docker compose logs --tail=30 tproxy'
```

Обновление релэя:

```bash
ssh user@SERVER 'cd /opt/tg-web-proxy && git pull || true'
# заново rsync с локальной машины:
./scripts/install-docker.sh --ssh user@SERVER --hostname ... --email ... --site ...
# или на VPS:
docker compose build --no-cache && docker compose up -d
```

### Камуфляжные сайты

6 готовых вариантов в `web/sites/` — см. [`web/sites/README.md`](web/sites/README.md).

| ID | Тема |
|---|---|
| `northwind-field` | полевые заметки, картография |
| `studio-garden` | ландшафтная студия |
| `atlas-books` | книжный магазин |
| `harbor-dental` | стоматология |
| `craft-roastery` | обжарка кофе |
| `pixel-repair` | ремонт техники |

Перед продом замените тексты и визуал на **свой уникальный** контент.

---

## Альтернатива: нативный install.sh (systemd на хосте)

Если Docker не подходит, используйте upstream-инсталлятор (ставит пакеты и
systemd прямо на Ubuntu/Debian):

```bash
sudo ./deploy/install.sh \
  --hostname proxy.example.com \
  --email you@example.com \
  --site-dir "$PWD/web/sites/studio-garden"
```

Подробности — в [`README.md`](README.md).

---

## Как работает WEB Proxy

```text
Telegram Desktop
  MTProto + MTProxy transform
        │
        ▼
  WebView → HTTPS :443 → Caddy → tproxy-server → MTProxy 127.0.0.1:2398
```

В клиенте только **hostname** и **ключ** (32 hex, опционально `dd`).

Share link (PoC):

```text
tg://webproxy?server=proxy.example.com&secret=<32hex>
```

Bridge capability: [`PROTOCOL.md`](PROTOCOL.md), проверка:

```bash
./scripts/bridge-capability.sh proxy.example.com <secret>
```

## Типичные поломки

| Симптом | Что проверить |
|---|---|
| WebView показывает сайт, не коннектит | hostname/secret ≠ профилю на сервере |
| Connecting… | HTTPS до hostname, `docker compose logs tproxy` |
| Нет сертификата | A-запись на IP, 80/443 до Caddy в контейнере |
| `readyz` fail | логи MTProxy внутри контейнера |

## Структура репозитория

| Путь | Назначение |
|---|---|
| `scripts/install-docker.sh` | автоматический Docker-деплой |
| `scripts/list-sites.sh` | список сайтов |
| `docker/` | Dockerfile, entrypoint, шаблоны |
| `web/sites/` | камуфляжные сайты |
| `deploy/install.sh` | нативная установка (без Docker) |
