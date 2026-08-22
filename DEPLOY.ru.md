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
tgwebpr uninstall
```

Конфиг: `/etc/default/tgwebpr`, код: `/opt/tg-web-proxy`.

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
