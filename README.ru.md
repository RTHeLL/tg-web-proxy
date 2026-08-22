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
tgwebpr          # меню
tgwebpr status   # контейнер, ready, https
tgwebpr creds    # hostname + key
tgwebpr logs     # логи
tgwebpr restart  # перезапуск
tgwebpr update   # git pull + rebuild
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
