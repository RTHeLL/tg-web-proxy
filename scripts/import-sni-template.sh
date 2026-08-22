#!/usr/bin/env bash
# Import and sanitize a site from DigneZzZ/remnawave-scripts sni-templates.
set -euo pipefail

usage() {
	cat <<'EOF'
import-sni-template.sh SOURCE_ID [TARGET_ID]

  SOURCE_ID  folder under sni-templates/ (e.g. speedtest, games-site)
  TARGET_ID  folder under web/sites/ (default: SOURCE_ID, lowercased)

Strips remote fonts/CDN links; keeps same-origin /assets/* JS/CSS.
EOF
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage && exit 0
[[ $# -lt 1 ]] && usage && exit 1

source_id="$1"
target_id="${2:-$source_id}"
target_id="$(printf '%s' "$target_id" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9-' '-')"

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dest="$root/web/sites/$target_id"
repo="DigneZzZ/remnawave-scripts"
src_prefix="sni-templates/$source_id"

api() {
	curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 \
		-H 'Accept: application/vnd.github+json' \
		"https://api.github.com/repos/${repo}/contents/${1}"
}

download_file() {
	path="$1"
	out="$2"
	mkdir -p "$(dirname "$out")"
	curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 \
		-o "$out" "https://raw.githubusercontent.com/${repo}/main/${path}"
}

walk() {
	local rel="$1"
	local entries
	entries="$(api "$rel")"
	python3 - <<'PY' "$entries" "$rel"
import json, sys
entries, rel = sys.argv[1], sys.argv[2]
for item in json.loads(entries):
    print(item["type"], item["path"], item.get("name", ""))
PY
}

rm -rf "$dest"
mkdir -p "$dest"

while IFS=$'\t' read -r kind path name; do
	[[ -z "$path" ]] && continue
	case "$kind" in
		file)
			download_file "$path" "$dest/$name"
			;;
		dir)
			mkdir -p "$dest/$name"
			sub="$(api "$path")"
			python3 - <<'PY' "$sub" "$dest/$name" "$repo"
import json, sys, subprocess
entries, dest, repo = json.loads(sys.argv[1]), sys.argv[2], sys.argv[3]

def fetch(path, out):
    subprocess.run([
        "curl", "--fail", "--silent", "--show-error", "--location",
        "--proto", "=https", "--tlsv1.2", "-o", out,
        f"https://raw.githubusercontent.com/{repo}/main/{path}",
    ], check=True)

for item in entries:
    if item["type"] == "file":
        fetch(item["path"], f"{dest}/{item['name']}")
PY
			;;
	esac
done < <(walk "$src_prefix")

if [[ ! -f "$dest/index.html" ]]; then
	echo "import failed: no index.html in $source_id" >&2
	exit 1
fi

# PUBLIC_SITE: no remote resources
sed -i \
	-e '/fonts\.googleapis\.com/d' \
	-e '/fonts\.gstatic\.com/d' \
	-e '/cdnjs\.cloudflare\.com/d' \
	-e '/cdn\.jsdelivr\.net/d' \
	"$dest/index.html" 2>/dev/null || \
sed -i '' \
	-e '/fonts\.googleapis\.com/d' \
	-e '/fonts\.gstatic\.com/d' \
	-e '/cdnjs\.cloudflare\.com/d' \
	-e '/cdn\.jsdelivr\.net/d' \
	"$dest/index.html"

if [[ -d "$dest/assets" ]]; then
	find "$dest/assets" -type f \( -name '*.css' -o -name '*.js' \) -print0 | while IFS= read -r -d '' f; do
		sed -i \
			-e '/fonts\.googleapis\.com/d' \
			-e '/fonts\.gstatic\.com/d' \
			-e 's/font-family:[^;]*Inter[^;]*/font-family: system-ui, -apple-system, Segoe UI, Roboto, sans-serif/g' \
			"$f" 2>/dev/null || \
		sed -i '' \
			-e '/fonts\.googleapis\.com/d' \
			-e '/fonts\.gstatic\.com/d' \
			-e 's/font-family:[^;]*Inter[^;]*/font-family: system-ui, -apple-system, Segoe UI, Roboto, sans-serif/g' \
			"$f"
	done
fi

site_title="$(grep -o '<title>[^<]*</title>' "$dest/index.html" | head -1 | sed 's/<[^>]*>//g' || true)"
site_title="${site_title:-$target_id}"

if [[ ! -f "$dest/robots.txt" ]]; then
	printf 'User-agent: *\nAllow: /\n' >"$dest/robots.txt"
fi

if [[ ! -f "$dest/about.html" ]]; then
	cat >"$dest/about.html" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>About — ${site_title}</title>
  <link rel="stylesheet" href="/assets/style.css">
  <link rel="icon" href="/favicon.svg" type="image/svg+xml">
</head>
<body>
  <main style="max-width:42rem;margin:2rem auto;padding:0 1rem;font-family:system-ui,sans-serif">
    <p><a href="/">← Home</a></p>
    <h1>About</h1>
    <p>This is a static demo site used for infrastructure testing.</p>
  </main>
</body>
</html>
EOF
fi

if [[ ! -f "$dest/privacy.html" ]]; then
	cat >"$dest/privacy.html" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Privacy — ${site_title}</title>
  <link rel="stylesheet" href="/assets/style.css">
  <link rel="icon" href="/favicon.svg" type="image/svg+xml">
</head>
<body>
  <main style="max-width:42rem;margin:2rem auto;padding:0 1rem;font-family:system-ui,sans-serif">
    <p><a href="/">← Home</a></p>
    <h1>Privacy</h1>
    <p>We do not collect personal data on this static demo site.</p>
  </main>
</body>
</html>
EOF
fi

if [[ ! -f "$dest/404.html" ]]; then
	cat >"$dest/404.html" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Not found — ${site_title}</title>
  <link rel="stylesheet" href="/assets/style.css">
  <link rel="icon" href="/favicon.svg" type="image/svg+xml">
</head>
<body>
  <main style="max-width:42rem;margin:2rem auto;padding:0 1rem;font-family:system-ui,sans-serif">
    <h1>404</h1>
    <p>Page not found. <a href="/">Return home</a></p>
  </main>
</body>
</html>
EOF
fi

echo "imported $source_id -> web/sites/$target_id"
