#!/usr/bin/env python3
"""Import sni-templates from DigneZzZ/remnawave-scripts into web/sites/."""
from __future__ import annotations

import json
import re
import subprocess
import sys
import urllib.request
from pathlib import Path

REPO = "DigneZzZ/remnawave-scripts"
BASE = f"https://raw.githubusercontent.com/{REPO}/main"
API = f"https://api.github.com/repos/{REPO}/contents"


def api(path: str) -> list[dict]:
    req = urllib.request.Request(
        f"{API}/{path}",
        headers={"Accept": "application/vnd.github+json", "User-Agent": "tg-web-proxy-import"},
    )
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.load(resp)


def download_raw(path: str, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    url = f"{BASE}/{path}"
    subprocess.run(
        ["curl", "--fail", "--silent", "--show-error", "--location", "--proto", "=https", "--tlsv1.2", "-o", str(dest), url],
        check=True,
    )


def import_tree(src_rel: str, dest: Path) -> None:
    if dest.exists():
        import shutil

        shutil.rmtree(dest)
    dest.mkdir(parents=True)

    def walk(rel: str, out: Path) -> None:
        for item in api(rel):
            name = item["name"]
            path = item["path"]
            if item["type"] == "file":
                download_raw(path, out / name)
            else:
                sub = out / name
                sub.mkdir(parents=True, exist_ok=True)
                walk(path, sub)

    walk(src_rel, dest)


def sanitize(dest: Path) -> None:
    remote = re.compile(r"fonts\.googleapis\.com|fonts\.gstatic\.com|cdnjs\.cloudflare\.com|cdn\.jsdelivr\.net")
    for html in dest.rglob("*.html"):
        text = html.read_text(encoding="utf-8", errors="replace")
        lines = [ln for ln in text.splitlines() if not remote.search(ln)]
        html.write_text("\n".join(lines) + ("\n" if text.endswith("\n") else ""), encoding="utf-8")
    for css in (dest / "assets").glob("*.css") if (dest / "assets").exists() else []:
        text = css.read_text(encoding="utf-8", errors="replace")
        text = remote.sub("", text)
        text = re.sub(
            r"font-family:[^;]*Inter[^;]*;",
            "font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif;",
            text,
        )
        css.write_text(text, encoding="utf-8")


def add_pages(dest: Path) -> None:
    index = dest / "index.html"
    title = "Site"
    if index.exists():
        m = re.search(r"<title>([^<]+)</title>", index.read_text(encoding="utf-8", errors="replace"))
        if m:
            title = m.group(1).strip()
    css_href = "/assets/style.css" if (dest / "assets" / "style.css").exists() else "/styles.css"
    icon = "/favicon.svg" if (dest / "favicon.svg").exists() else "/favicon.ico"

    def page(name: str, heading: str, body: str) -> str:
        return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{heading} — {title}</title>
  <link rel="stylesheet" href="{css_href}">
  <link rel="icon" href="{icon}">
</head>
<body>
  <main class="legal-page">
    <p><a href="/">← Home</a></p>
    <h1>{heading}</h1>
    <p>{body}</p>
  </main>
</body>
</html>
"""

    extras = {
        "robots.txt": "User-agent: *\nAllow: /\n",
        "about.html": page("about", "About", "Static demo site for infrastructure testing."),
        "privacy.html": page("privacy", "Privacy", "This demo site does not collect personal data."),
        "404.html": page("404", "404", "Page not found."),
    }
    for name, content in extras.items():
        path = dest / name
        if not path.exists():
            path.write_text(content, encoding="utf-8")

    css_path = dest / "assets" / "style.css"
    if css_path.exists():
        css = css_path.read_text(encoding="utf-8", errors="replace")
        if ".legal-page" not in css:
            css += "\n.legal-page{max-width:42rem;margin:2rem auto;padding:0 1rem}\n"
            css_path.write_text(css, encoding="utf-8")


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    sites_dir = root / "web" / "sites"
    mappings = [
        ("speedtest", "speedtest"),
        ("games-site", "games-site"),
        ("filecloud", "filecloud"),
        ("modmanager", "modmanager"),
        ("downloader", "downloader"),
        ("converter", "converter"),
        ("10gag", "meme-board"),
        ("convertit", "video-convert"),
        ("YouTube", "video-host"),
    ]
    for src, dst in mappings:
        print(f"import {src} -> {dst}")
        dest = sites_dir / dst
        import_tree(f"sni-templates/{src}", dest)
        sanitize(dest)
        add_pages(dest)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
