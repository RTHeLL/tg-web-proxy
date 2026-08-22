# Public site packages

Static camouflage sites live under [`../sites/`](../sites/). Each subdirectory is a self-contained package for `--site-dir` / Docker `--site`.

List available variants:

```bash
./scripts/list-sites.sh
```

Example deploy path:

```bash
sudo ./deploy/install.sh \
  --hostname proxy.example.com \
  --email operator@example.com \
  --site-dir "$PWD/web/sites/northwind-field"
```

See [`PUBLIC_SITE.md`](../../PUBLIC_SITE.md) for the full site package contract.

Before production, replace copy and visuals with operator-owned unique content.
