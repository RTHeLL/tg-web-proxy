# tg-web-proxy

WEB-прокси для Telegram Desktop 7.1.1+ (hostname + key).

## Установка

DNS: `A` домена → IP сервера. Порты 80/443 свободны. Root.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/RTHeLL/tg-web-proxy/main/install.sh)
```

Спросит домен, email, номер сайта-обложки, сгенерирует key.

## Управление

После установки:

```bash
tgwebpr            # меню
tgwebpr status
tgwebpr creds      # hostname + key
tgwebpr logs       # Ctrl+C → обратно в меню
tgwebpr restart
tgwebpr update     # git pull (если DNS ок) + rebuild
tgwebpr site       # сменить HTML-шаблон (12+ вариантов)
tgwebpr carrier    # режим транспорта (websocket для Desktop)
tgwebpr proxy        # backend telemt/mtproxy, ad tag, ME pool
tgwebpr uninstall
```

## Флаги установки

```bash
bash <(curl -fsSL .../install.sh) \
  --hostname tweb.example.com \
  --email you@example.com \
  --site 2 \
  -y
```

`--site` — номер 1–6 или id (`craft-roastery`).

| № | id |
|---|---|
| 1 | northwind-field |
| 2 | studio-garden |
| 3 | atlas-books |
| 4 | harbor-dental |
| 5 | craft-roastery |
| 6 | pixel-repair |

Подробнее: [DEPLOY.ru.md](DEPLOY.ru.md)
