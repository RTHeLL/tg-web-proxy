# Деплой

## Быстрый путь

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/RTHeLL/tg-web-proxy/main/install.sh)
```

Интерактивно спросит hostname, email, сайт. Флаги `-y`, `--hostname`, `--email`, `--site` — если не хочешь диалог.

Перед запуском: `A`-запись на IP, 80/443 открыты, root.

Повторный запуск тянет свежий `main` из git и пересобирает контейнер.

## Сайты

Папки в `web/sites/` — статика для камуфляжа. Id совпадает с `--site`:

`northwind-field` `studio-garden` `atlas-books` `harbor-dental` `craft-roastery` `pixel-repair`

## Проверка

```bash
curl -fsS https://YOUR.HOST/
cd /opt/tg-web-proxy && docker compose ps
cd /opt/tg-web-proxy && docker compose logs --tail=50 tproxy
```

## Permission denied на ./scripts/...

Git с Windows часто не даёт +x. Обход:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/RTHeLL/tg-web-proxy/main/install.sh)
# или
bash /opt/tg-web-proxy/scripts/list-sites.sh
```

## Без Docker

```bash
git clone https://github.com/RTHeLL/tg-web-proxy.git /opt/tg-web-proxy
cd /opt/tg-web-proxy
sudo bash deploy/install.sh \
  --hostname proxy.example.com \
  --email you@example.com \
  --site-dir "$PWD/web/sites/studio-garden"
```

## Частые косяки

- **80/443 заняты** — убери nginx/caddy на хосте
- **нет сертификата** — A напрямую на сервер, без Cloudflare proxy
- **Connecting в TG** — hostname/key должны совпадать с `.env`
- **Permission denied** — запускай через `bash`, не `./`

Схема: Desktop → HTTPS → Caddy → tproxy-server → MTProxy. Не путать с `tg-ws-proxy`. Wire-формат — `PROTOCOL.md`.
