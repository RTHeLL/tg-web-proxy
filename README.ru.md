# tg-web-proxy

Серверная часть для **WEB**-прокси в Telegram Desktop (7.1.1+). В клиенте два поля: hostname и ключ. Трафик идёт через WebView как обычный HTTPS; снаружи — статический сайт.

Взято за основу [tproxy-server](https://github.com/telegramdesktop/tproxy-server) от john-preston, поверх — docker-обвязка и несколько сайтов-камуфляжей.

## Поставить на VPS

DNS: `A` на IP сервера. Порты 80/443 свободны. Запуск от root.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/RTHeLL/tg-web-proxy/main/install.sh)
```

Без флагов скрипт сам спросит hostname, email и какой сайт показывать. Можно и так:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/RTHeLL/tg-web-proxy/main/install.sh) \
  --hostname proxy.example.com \
  --email you@example.com \
  --site craft-roastery \
  -y
```

Ставит docker (если нет), клонирует в `/opt/tg-web-proxy`, собирает контейнер. В конце печатает hostname и secret.

### Сайты (`--site`)

`northwind-field` · `studio-garden` · `atlas-books` · `harbor-dental` · `craft-roastery` · `pixel-repair`

По умолчанию в меню — `studio-garden`. Тексты лучше потом заменить на свои.

### Если что-то пошло не так

```bash
curl -fsS https://proxy.example.com/
cd /opt/tg-web-proxy && docker compose ps
cd /opt/tg-web-proxy && docker compose logs -f tproxy
```

В Desktop: тип **WEB**, hostname и key из вывода установщика.

---

Ещё: [DEPLOY.ru.md](DEPLOY.ru.md) · upstream [README.md](README.md)
