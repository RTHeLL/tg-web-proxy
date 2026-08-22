# tg-web-proxy

WEB-прокси для Telegram Desktop 7.1.1+ (hostname + key).

## Установка

DNS: `A` домена → IP сервера. Порты 80/443 свободны. Root.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/RTHeLL/tg-web-proxy/main/install.sh)
```

Спросит домен, email, шаблон сайта-обложки, сгенерирует key.

## Управление

```bash
tgwebpr            # меню
tgwebpr status
tgwebpr creds      # hostname + key
tgwebpr logs
tgwebpr restart
tgwebpr update
tgwebpr site       # сменить HTML-шаблон
tgwebpr carrier    # режим транспорта
tgwebpr proxy      # backend, ad tag, ME pool
tgwebpr uninstall
```

## Флаги установки

```bash
bash <(curl -fsSL .../install.sh) \
  --hostname tweb.example.com \
  --email you@example.com \
  --site speedtest \
  -y
```

`--site` — id папки из `web/sites/` (например `speedtest`, `games-site`) или номер из меню установщика.

Подробнее: [DEPLOY.ru.md](DEPLOY.ru.md)
