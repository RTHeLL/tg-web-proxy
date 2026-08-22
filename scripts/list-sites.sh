#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
sites_dir="$root/web/sites"

if [[ ! -d "$sites_dir" ]]; then
	echo "no sites directory: $sites_dir" >&2
	exit 1
fi

echo "Available site variants:"
for dir in "$sites_dir"/*; do
	[[ -d "$dir" ]] || continue
	name="$(basename "$dir")"
	[[ "$name" == "README.md" ]] && continue
	if [[ -f "$dir/index.html" ]]; then
		title="$(grep -o '<title>[^<]*</title>' "$dir/index.html" | head -1 | sed 's/<[^>]*>//g')"
		printf '  - %s (%s)\n' "$name" "${title:-no title}"
	else
		printf '  - %s (missing index.html)\n' "$name"
	fi
done
