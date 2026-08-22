# Деплой Telegram WEB Proxy

## Установка одной командой

На VPS под **root** (или `sudo bash`):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/RTHeLL/tg-web-proxy/main/install.sh) \
  --hostname proxy.example.com \
  --email you@example.com \
  --site craft-roastery
```

**До запуска:** DNS `A` hostname → IP сервера (без CDN), открыты TCP **80/443**.

Скрипт:
1. ставит Docker Engine + Compose (Debian/Ubuntu), если их нет;
2. клонирует/обновляет `/opt/tg-web-proxy`;
3. собирает контейнер (Caddy + tproxy-server + MTProxy);
4. печатает hostname и secret для Telegram Desktop.

Повторный запуск обновляет код из git и пересобирает стек.

### Сайты-камуфляж

```text
northwind-field  studio-garden  atlas-books
harbor-dental    craft-roastery pixel-repair
```

По умолчанию: `studio-garden`.

### Проверка

```bash
curl --fail https://proxy.example.com/
cd /opt/tg-web-proxy && docker compose ps
cd /opt/tg-web-proxy && docker compose logs --tail=50 tproxy
```

### Telegram Desktop

Тип **WEB** → hostname + ключ из вывода установщика.

---

## Если «Permission denied» на скрипты

После `git clone` на Windows-битые права не мешают — используйте установщик через `bash`:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/RTHeLL/tg-web-proxy/main/install.sh) ...
```

Или явно:

```bash
bash /opt/tg-web-proxy/scripts/list-sites.sh
bash /opt/tg-web-proxy/scripts/install-docker.sh --local --hostname ... --email ... --site ...
```

---

## Как это устроено

```text
Telegram Desktop → WebView (HTTPS) → Caddy → tproxy-server → MTProxy
```

Снаружи — обычный сайт; внутри контейнера релей разбирает мультиплекс.

Это **не** `tg-ws-proxy`. Протокол: [`PROTOCOL.md`](PROTOCOL.md).

---

## Альтернатива: systemd без Docker

```bash
git clone https://github.com/RTHeLL/tg-web-proxy.git /opt/tg-web-proxy
cd /opt/tg-web-proxy
sudo bash deploy/install.sh \
  --hostname proxy.example.com \
  --email you@example.com \
  --site-dir "$PWD/web/sites/studio-garden"
```

---

## Типичные ошибки

| Симптом | Решение |
|---|---|
| `Permission denied` на `./scripts/...` | запускайте через `bash script.sh` или one-liner выше |
| порт 80/443 занят | освободите (nginx/apache/caddy на хосте) |
| сертификат не выдаётся | A-запись напрямую на IP, без Cloudflare proxy |
| Connecting в Telegram | hostname/secret должны совпадать с `.env` |
