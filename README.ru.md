# tg-test-web-proxy

Рабочая копия серверной части **Telegram WEB Proxy**
([telegramdesktop/tproxy-server](https://github.com/telegramdesktop/tproxy-server)).

Клиент: Telegram Desktop **≥ 7.1.1** (тип **WEB**: hostname + ключ).

## Быстрый старт (Docker)

```bash
./scripts/list-sites.sh

./scripts/install-docker.sh \
  --ssh user@YOUR_SERVER \
  --hostname proxy.example.com \
  --email you@example.com \
  --site craft-roastery
```

На VPS заранее: Docker, открытые 80/443, DNS A на hostname.

Полная инструкция: **[DEPLOY.ru.md](DEPLOY.ru.md)**

## Камуфляжные сайты

6 вариантов в `web/sites/` — `northwind-field`, `studio-garden`, `atlas-books`,
`harbor-dental`, `craft-roastery`, `pixel-repair`.

## Локальные дополнения

- Docker-стек и `scripts/install-docker.sh`
- Каталог сайтов `web/sites/`
- `DEPLOY.ru.md`, `scripts/gen-secret.sh`, `scripts/bridge-capability.sh`

Upstream: [`UPSTREAM.md`](UPSTREAM.md)
