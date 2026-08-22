# Upstream tracking

This tree is based on:

- Repository: https://github.com/telegramdesktop/tproxy-server
- Default branch: `master`
- Author / maintainer: john-preston (Telegram Desktop)

Local additions not present in upstream:

| Path | Purpose |
|---|---|
| `README.ru.md` | Short Russian entry point |
| `DEPLOY.ru.md` | Russian deployment + protocol overview |
| `web/public/` | redirect note; packages live in `web/sites/` |
| `web/sites/` | six camouflage static site variants |
| `scripts/install-docker.sh` | one-command Docker deployment |
| `scripts/list-sites.sh` | list site variants |
| `docker/` | Dockerfile, compose templates, entrypoint |
| `UPSTREAM.md` | This file |

When syncing from upstream, prefer merging/rebasing against
`telegramdesktop/tproxy-server` and keep the files above.
