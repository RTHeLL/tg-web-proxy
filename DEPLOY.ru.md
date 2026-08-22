# Деплой

## Установка

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/RTHeLL/tg-web-proxy/main/install.sh)
```

Нужно: root, DNS A на сервер, 80/443 свободны. Docker можно не ставить заранее — установщик предложит установку или запуск **после вашего подтверждения** (флаг `-y` — без лишних вопросов).

## Управление — tgwebpr

```bash
tgwebpr              # меню
tgwebpr status       # состояние сервиса
tgwebpr creds        # hostname и key для Telegram
tgwebpr logs         # логи (Ctrl+C — выход)
tgwebpr restart
tgwebpr update       # обновление с GitHub и пересборка
tgwebpr site         # сменить HTML-шаблон сайта
tgwebpr carrier      # режим транспорта
tgwebpr proxy        # backend, рекламный канал, ME pool
tgwebpr uninstall
```

Код: `/opt/tg-web-proxy`, конфиг: `.env` в том же каталоге.

## Подключение в Telegram

Desktop **≥ 7.1.1** → Settings → Advanced → Proxy → Add Proxy → **WEB**.

Hostname и key: `tgwebpr creds` или ссылка `tg://webproxy?server=...&secret=...`.

## Telegram «подключён», но чаты не грузятся

1. `tgwebpr status` — `Ready : да`, HTTPS открывается.
2. `tgwebpr carrier` → **websocket** (режим по умолчанию для Desktop).
3. `tgwebpr restart`
4. В Telegram удалите старый WEB proxy и добавьте заново (`tgwebpr creds`).

Если websocket блокируется провайдером — попробуйте `https-lanes` в `tgwebpr carrier`.

## Рекламный канал (promo)

Через [@MTProxybot](https://t.me/MTProxybot):

1. Добавьте прокси: **ваш домен:443** и secret из `tgwebpr creds` (это WEB proxy, не обычный `tg://proxy`).
2. Получите ad tag (32 hex) → `tgwebpr proxy` → пункт 4.
3. В боте: `/myproxies` → **Set promotion** → публичная ссылка на канал.

**WEB proxy ≠ обычный MTProxy:** ссылка для пользователей — `tg://webproxy?...`, не `tg://proxy?...` из бота.

Если канал не виден: проверьте с другого аккаунта (если уже подписаны — Telegram не показывает promo), подождите до часа, переподключите WEB proxy в Telegram.

## Сайт на домене

При установке выбирается HTML-шаблон — он открывается по `https://ваш-домен/` в браузере. На работу прокси не влияет, это только «обложка». Список шаблонов: `tgwebpr site`.

## Без Docker

```bash
sudo bash deploy/install.sh \
  --hostname proxy.example.com \
  --email you@example.com \
  --site-dir "$PWD/web/sites/studio-garden"
```

## Частые проблемы

| Симптом | Что сделать |
|---|---|
| Docker не найден | установщик предложит установку на шаге 2; можно отказаться и поставить Docker вручную |
| 80/443 заняты | освободите порты (nginx/apache/caddy на хосте) |
| Connecting в TG | `tgwebpr creds` — сверить hostname и key |
| Подключён, но пусто | `tgwebpr carrier` → websocket, `tgwebpr restart`, пересоздать proxy в Telegram |
| Promo не появился | зарегистрировать WEB proxy в @MTProxybot, ad tag в `tgwebpr proxy`, Set promotion |
| Ошибка сборки Docker (network unreachable) | `tgwebpr update`; на VPS без IPv6 — отключить IPv6 и перезапустить Docker |
