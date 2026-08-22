#!/usr/bin/env bash
# Generate a client-facing WEB/MTProxy secret (32 lowercase hex bytes).
# Optional: pass "dd" as first argument to enable padded MTProxy mode.
set -euo pipefail

prefix=""
if [[ "${1:-}" == "dd" ]]; then
	prefix="dd"
fi

secret="$(openssl rand -hex 16)"
printf '%s%s\n' "$prefix" "$secret"
