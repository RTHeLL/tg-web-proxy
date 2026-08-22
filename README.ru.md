# tg-web-proxy

Telegram **WEB Proxy** для Desktop (≥ 7.1.1): hostname + ключ, трафик через HTTPS/WebView.

Основано на [telegramdesktop/tproxy-server](https://github.com/telegramdesktop/tproxy-server).

## Установка (одна команда на VPS)

DNS: `A`-запись hostname → IP сервера. Открыты **TCP 80/443**. Root.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/RTHeLL/tg-web-proxy/main/install.sh) \
  --hostname proxy.example.com \
  --email you@example.com \
  --site craft-roastery
```

Скрипт сам поставит Docker (если нет), клонирует репозиторий в `/opt/tg-web-proxy`,
соберёт контейнер и выведет **hostname + secret** для Telegram Desktop.

### Камуфляжные сайты (`--site`)

| ID | Тема |
|---|---|
| `northwind-field` | полевые заметки |
| `studio-garden` | ландшафтная студия *(по умолчанию)* |
| `atlas-books` | книжный |
| `harbor-dental` | стоматология |
| `craft-roastery` | обжарка кофе |
| `pixel-repair` | ремонт техники |

### Флаги

| Флаг | По умолчанию | Назначение |
|---|---|---|
| `--hostname` | — | публичный DNS (обязателен) |
| `--email` | — | email для Let's Encrypt (обязателен) |
| `--site` | `studio-garden` | вариант сайта-камуфляжа |
| `--secret` | случайный | ключ WEB proxy (32 hex, опционально `dd`) |

### После установки

```bash
curl --fail https://proxy.example.com/
docker compose -f /opt/tg-web-proxy/docker-compose.yml ps
docker compose -f /opt/tg-web-proxy/docker-compose.yml logs -f tproxy
```

Telegram Desktop → **WEB** proxy → hostname + key из вывода установщика.

Share link (PoC): `tg://webproxy?server=HOST&secret=SECRET`

---

Подробности: **[DEPLOY.ru.md](DEPLOY.ru.md)** · upstream **[README.md](README.md)**
