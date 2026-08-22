# Public website backends

Every relay hostname needs an operator-owned website. It is input to the relay,
not part of the transport implementation, and this repository deliberately ships
no shared starter. A common default would give unrelated relay hosts identical
bodies and assets that are easy to recognize with an active probe.

Choose exactly one source in the server configuration:

- `public_dir` loads a self-contained static site into relay memory; or
- `public_upstream` delegates the public surface to a full HTTP application on a
  numeric loopback address.

## Static directory

Point `public_dir` at a directory with this shape:

```text
my-site/
├── index.html          # required; also the response to an invalid root query
├── 404.html            # optional; index.html is the fallback
├── about.html          # optional; available as /about and /about.html
├── privacy.html        # optional; available as /privacy and /privacy.html
├── styles.css
├── favicon.svg         # also answers /favicon.ico
├── robots.txt
└── assets/
    └── photograph.webp
```

The relay recursively loads regular files when it starts. Symlinks and other
non-regular entries are not served. Exact paths resolve first, then an
extensionless request such as `/notes/first` may resolve `notes/first.html`.
There is no arbitrary single-page-app fallback and no server-side application,
redirect, route, or per-page header hook.

Keep the package self-contained. The public response policy permits same-origin
styles, images, fonts, and external scripts, but blocks inline scripts and styles,
third-party resources, workers, framing, forms, camera, microphone, and location.
Use ordinary relative or root-relative URLs. In particular, a typical generated
site should use `<link rel="stylesheet" href="/styles.css">` instead of an inline
`<style>` block.

The bridge document is generated separately by the relay. Public HTML, JavaScript,
CSS, and assets are never inserted into it and cannot alter the bridge transport.

## Creating a site

This is enough direction for a code or site generator:

> Create a distinctive, self-contained static website with three to five HTML
> pages, shared external CSS, an SVG favicon, a custom 404 page, and no remote
> resources. Use plain HTML/CSS and optional same-origin external JavaScript. Do
> not use inline script, inline CSS, forms, analytics, service workers, frames, or
> a client-side router. Output only deployable files, with `index.html` at the
> root and ordinary `.html` files for clean extensionless links.

Use real operator-owned names, copy, visuals, and structure. Merely changing a
title or color in a widely reused template leaves most of the active-probe
fingerprint shared.

### Install and update

A fresh automated installation takes the source directory explicitly:

```bash
sudo ./deploy/install.sh \
  --hostname proxy.example.com \
  --email operator@example.com \
  --site-dir /path/to/my-site
```

The installer copies it to `/srv/tproxy-site`. Re-running the installer preserves
an existing deployed site even if `--site-dir` is supplied.

To change the site, replace the files under `/srv/tproxy-site`, keep them readable
by the `tproxy` service, validate the complete configuration, and restart only the
relay:

```bash
sudo /usr/local/bin/tproxy-server \
  -config /etc/tproxy-server/config.json \
  -profiles-file /etc/tproxy-server/profiles.json \
  -check
sudo systemctl restart tproxy-server
curl --fail https://proxy.example.com/
```

The relay holds the complete site in memory to give the static surface and invalid
transport requests the same response path. File changes therefore become visible
only after a restart. Do not configure Caddy or another front proxy to serve some
of these files directly: that would reintroduce observable differences between
ordinary and relay-owned paths.

## Private web application

For server-side rendering, a database, accounts, forms, a CMS, application APIs,
SSE, or WebSockets, run any ordinary HTTP server on a numeric loopback address and
configure it as the public source:

```json
{
  "public_dir": "",
  "public_upstream": "http://127.0.0.1:3000"
}
```

The URL must contain only `http`, a numeric loopback address, and an explicit
port; it has no trailing slash or path. The application must not listen on a
public interface. Manage its process, framework, database, health checks, and
updates independently from the relay.

The relay forwards ordinary request methods, paths, query strings, bodies, and
the original `Host`, then streams the application's response. The application
owns public-site cookies, authentication, CSP, caching, and other headers. It may
use any language or framework and may serve its own WebSockets. No in-process
plugin ABI, template language, or relay rebuild is involved. The application also
chooses its normal route-specific request-body limits. The public Caddy gateway
deliberately has no common byte threshold: a hostname-wide limit would be easy to
measure with an active probe. Authenticated carrier bodies remain independently
bounded by the relay's `max_body_bytes` setting.

These transport endpoints are reserved and must not be site routes:

```text
GET /?bridge=<capability>
/api/v1/session
/api/v1/up
/api/v1/down
/api/v1/ws
```

Only a valid bridge capability or session credential is handled as transport.
Unauthenticated requests at reserved paths fall back through the site application
with transport headers and bodies removed, so the application supplies its normal
not-found response without receiving carrier credentials or opaque Telegram data.
A valid bridge is generated entirely by the relay and never loads application
HTML or assets.

Do not route the application directly from Caddy. Caddy must continue to send
every request on the hostname to `tproxy-server`; otherwise the special root and
carrier requests cannot be intercepted and the extra routing surface becomes
probeable.

A fresh installation can select this mode directly:

```bash
sudo ./deploy/install.sh \
  --hostname proxy.example.com \
  --email operator@example.com \
  --site-upstream http://127.0.0.1:3000
```

This is a suitable request for a code generator:

> Create a production-oriented website application in the chosen framework. Bind
> plain HTTP only to `127.0.0.1:3000`; do not terminate TLS. Include several real
> pages, a custom not-found response, static assets, a health endpoint, persistent
> storage only where the product needs it, and a hardened systemd unit. Do not
> define `/api/v1/session`, `/api/v1/up`, `/api/v1/down`, or `/api/v1/ws`. Treat
> unknown query parameters on `/` normally. Do not mention or imitate Telegram or
> a proxy in the public content.
