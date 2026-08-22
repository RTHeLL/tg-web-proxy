# Сайты-обложки

Список: `bash scripts/list-sites.sh`

## Из [remnawave sni-templates](https://github.com/DigneZzZ/remnawave-scripts/tree/main/sni-templates)

| id | тип |
|---|---|
| `speedtest` | тест скорости |
| `games-site` | ретро-игры |
| `filecloud` | облачное хранилище |
| `modmanager` | мод-менеджер |
| `downloader` | загрузчик |
| `converter` | конвертер файлов |
| `meme-board` | мемы (10gag) |
| `video-convert` | видео-конвертер |
| `video-host` | видеохостинг |

Импорт обновлённых версий:

```bash
python scripts/import-sni-templates.py
```

Удаляются ссылки на Google Fonts и другие CDN — только same-origin `/assets/*`.

## Свои шаблоны

| id | тип |
|---|---|
| `trace-board` | analytics dashboard |
| `node-panel` | VPS/hosting panel |
| `tap-menu` | QR-меню ресторана |

## Установка

```bash
tgwebpr site              # меню — все папки web/sites/*
bash install.sh --site speedtest
```

Старые шаблоны (`northwind-field`, `pixel-repair`, …) можно удалить вручную — они больше не в меню по умолчанию.
