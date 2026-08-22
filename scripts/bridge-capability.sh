#!/usr/bin/env bash
# Derive the one-shot bridge capability for a hostname + secret pair.
# Usage: ./scripts/bridge-capability.sh <hostname> <secret-hex>
# Does NOT print the full bridge URL (operators should keep that out of logs).
set -euo pipefail

hostname="${1:-}"
secret_hex="${2:-}"

if [[ -z "$hostname" || -z "$secret_hex" ]]; then
	echo "usage: $0 <hostname> <32-hex-secret|[dd]32-hex>" >&2
	exit 2
fi

if [[ ! "$hostname" =~ ^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$ ]] || [[ "$hostname" != *.* ]]; then
	echo "hostname must be lowercase ASCII DNS" >&2
	exit 2
fi

if [[ ! "$secret_hex" =~ ^([0-9a-f]{32}|dd[0-9a-f]{32})$ ]]; then
	echo "secret must be 32 lowercase hex chars, optionally prefixed with dd" >&2
	exit 2
fi

# PROTOCOL.md: HMAC-SHA256(key=S, message="tdesktop-web-proxy-bridge-v1\n" + H)
capability="$(
	printf 'tdesktop-web-proxy-bridge-v1\n%s' "$hostname" \
		| openssl dgst -sha256 -mac HMAC -macopt "hexkey:${secret_hex}" -binary \
		| openssl base64 -A \
		| tr '+/' '-_' \
		| tr -d '='
)"

# Sanity-check against PROTOCOL.md vector when using the documented sample.
if [[ "$hostname" == "proxy.example.com" && "$secret_hex" == "000102030405060708090a0b0c0d0e0f" ]]; then
	expected="MHLEY5PmW1GWqJkSrlmJpvJUiLhBH_QKy6yKg8a0JPk"
	if [[ "$capability" != "$expected" ]]; then
		echo "vector mismatch: got $capability want $expected" >&2
		exit 1
	fi
fi

echo "hostname=$hostname"
echo "bridge_capability=$capability"
echo "note=open https://$hostname/?bridge=<capability> only in a trusted client; do not paste into shared logs"
