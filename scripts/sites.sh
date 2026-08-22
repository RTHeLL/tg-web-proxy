#!/usr/bin/env bash
# Shared site catalog for installer and tgwebpr.
set -euo pipefail

sites_root() {
	local root="${1:-}"
	if [[ -z "$root" ]]; then
		root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
	fi
	printf '%s/web/sites' "$root"
}

load_site_catalog() {
	local root="${1:-}"
	local dir name title
	SITE_IDS=()
	SITE_LABELS=()
	local sites_dir
	sites_dir="$(sites_root "$root")"
	[[ -d "$sites_dir" ]] || return 0
	for dir in "$sites_dir"/*; do
		[[ -d "$dir" && -f "$dir/index.html" ]] || continue
		name="$(basename "$dir")"
		title="$(grep -o '<title>[^<]*</title>' "$dir/index.html" 2>/dev/null | head -1 | sed 's/<[^>]*>//g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
		[[ -z "$title" ]] && title="$name"
		SITE_IDS+=("$name")
		SITE_LABELS+=("$title")
	done
}

site_label_for() {
	local id="$1"
	local i
	for i in "${!SITE_IDS[@]}"; do
		if [[ "${SITE_IDS[$i]}" == "$id" ]]; then
			printf '%s' "${SITE_LABELS[$i]}"
			return 0
		fi
	done
	printf '%s' "$id"
}
