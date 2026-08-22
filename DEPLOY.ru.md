# Деплой

## Установка

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/RTHeLL/tg-web-proxy/main/install.sh)
```

Нужно: root, DNS A на сервер, 80/443 свободны.

## Управление — tgwebpr

```bash
tgwebpr              # меню (чистый экран)
tgwebpr status
tgwebpr creds
tgwebpr logs         # Ctrl+C возвращает в меню
tgwebpr restart
tgwebpr update       # если github.com не резолвится — rebuild с диска
tgwebpr site         # сменить шаблон 1–6
tgwebpr carrier      # режим транспорта (см. ниже)
tgwebpr proxy        # backend, ad tag (@MTProxybot), ME pool
tgwebpr uninstall
```

Конфиг: `/etc/default/tgwebpr`, код: `/opt/tg-web-proxy`.

## Telegram Desktop не грузит чаты

Симптомы: сайт по HTTPS открывается, в TG «подключён», но сообщения не идут; при первом входе — *The built-in web transport couldn't connect*; вкладка браузера из TG показывает *Connected* и потом *Telegram Desktop disconnected*.

**Что происходит:** основной путь — встроенный WebView в Telegram Desktop. Вкладка браузера — запасной вариант, когда WebView не поднялся; её закрытие/разрыв с Desktop — нормальное поведение, это не «основной режим».

**Что сделать на сервере:**

```bash
sudo tgwebpr update          # подтянет CARRIER_MODE=websocket и пересоберёт образ
# или вручную:
sudo tgwebpr carrier         # пункт 3 — websocket
sudo tgwebpr restart
```

Проверка: `tgwebpr status` — строка `Carrier : websocket`, `Ready : да`.

В Telegram: Settings → Advanced → Proxy → удалить старый WEB proxy и добавить заново (`tgwebpr creds`). Desktop **≥ 7.1.1**.

| Режим carrier | Когда |
|---|---|
| `websocket` | Telegram Desktop (рекомендуется) |
| `https-lanes` | если websocket блокируется, но HTTP проходит |
| `https` | совместимость, на Desktop часто «подключён без трафика» |

## MTProxy / telemt — ad tag и backend

Рекламный канал (promo) задаётся через [@MTProxybot](https://t.me/MTProxybot) — 32 hex-символа:

```bash
tgwebpr proxy          # пункт 4 — ad tag
```

**Важно — WEB proxy ≠ обычный MTProxy:**

| | Обычный `tg://proxy` | WEB `tg://webproxy` |
|---|---|---|
| Регистрация в боте | IP:443 + secret | **домен:443** + **WEB secret** (`tgwebpr creds`) |
| Ссылка для юзеров | `tg://proxy?...` | `tg://webproxy?...` — **не** ссылка из бота |
| ME pool (telemt) | — | **нужен `true`**, если задан ad tag |

**Почему канал не виден:**

1. В боте зарегистрирован старый MTProxy, а клиенты сидят на **WEB** — добавьте прокси заново: `tweb.kurduk.store:443` и secret из `tgwebpr creds`.
2. В боте: `/myproxies` → ваш сервер → **Set promotion** → публичная ссылка на канал (не private).
3. **`TELEMT_MIDDLE_PROXY=true`** — включается автоматически при `MTPROXY_AD_TAG`; без ME pool ad tag в telemt не работает.
4. Если вы **уже подписаны** на promo-канал — Telegram его не показывает (проверьте с другого аккаунта).
5. Обновление на серверах Telegram — до **~1 часа**.
6. Desktop WEB — sponsored channel привязан к backend tag; если после пунктов 1–4 не появился, проверьте `docker exec tg-web-proxy cat /etc/telemt/telemt.toml | grep ad_tag`.

После смены ad tag: `tgwebpr restart`, переподключите WEB proxy в Telegram.

Там же в `tgwebpr proxy`:
- **backend** — `telemt` (рекомендуется) или `mtproxy` (official)
- **carrier** — `websocket` для Desktop
- **ME pool** — middle-end proxy в telemt (`true`/`false`, по умолчанию `false`)

После смены — контейнер перезапускается автоматически.

## Шаг «сайт на домене» при установке

Пункты 1–6 — готовые HTML-страницы. Они открываются по `https://ваш-домен/` в браузере.  
На WEB-прокси это не влияет — только то, что увидит тот, кто зайдёт на сайт.

## Без Docker

```bash
sudo bash deploy/install.sh \
  --hostname proxy.example.com \
  --email you@example.com \
  --site-dir "$PWD/web/sites/studio-garden"
```

## Косяки

| Что | Что делать |
|---|---|
| Permission denied на `./scripts` | `bash script.sh` или one-liner выше |
| 80/443 заняты | убрать nginx/caddy на хосте |
| Connecting в TG | `tgwebpr creds` — сверить hostname/key |
| Подключён, но пусто | `BACKEND=telemt` в `.env` + `tgwebpr update`; переподключить proxy в TG |
| `docker.io ... network is unreachable` (IPv6) | убрали лишний pull в Dockerfile; если снова — отключить IPv6 на VPS (см. ниже) |

### Docker build: `registry-1.docker.io ... network is unreachable`

На VPS без рабочего IPv6 Docker иногда лезет в Hub по IPv6 и падает. После `git pull` / обновления кода пересоберите:

```bash
cd /opt/tg-web-proxy && docker compose --env-file .env build
```

Если ошибка осталась — временно отключите IPv6 и перезапустите Docker:

```bash
sysctl -w net.ipv6.conf.all.disable_ipv6=1
sysctl -w net.ipv6.conf.default.disable_ipv6=1
systemctl restart docker
cd /opt/tg-web-proxy && docker compose --env-file .env build && docker compose --env-file .env up -d
```
