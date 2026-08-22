#!/usr/bin/env bash
# Telegram WEB Proxy — one-command installer (Docker).
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/RTHeLL/tg-web-proxy/main/install.sh) \
#     --hostname proxy.example.com \
#     --email you@example.com \
#     --site craft-roastery
#
# Requirements: root (or sudo), curl, git, x86_64 Linux, DNS A -> this host, TCP 80/443 open.
set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-/opt/tg-web-proxy}"
REPO_URL="${REPO_URL:-https://github.com/RTHeLL/tg-web-proxy.git}"
REPO_REF="${REPO_REF:-main}"

hostname=""
email=""
site="studio-garden"
secret=""
dry_run=0

usage() {
	cat <<'EOF'
Telegram WEB Proxy installer

usage:
  install.sh --hostname FQDN --email ADDR [--site NAME] [--secret HEX]

options:
  --hostname   public DNS name (lowercase, no scheme/port)
  --email      ACME contact email for HTTPS certificate
  --site       camouflage site id (default: studio-garden)
  --secret     32 hex chars, optional dd prefix (auto-generated if omitted)
  --dry-run    show planned actions only

sites:
  northwind-field  studio-garden  atlas-books
  harbor-dental    craft-roastery pixel-repair

example:
  bash <(curl -fsSL https://raw.githubusercontent.com/RTHeLL/tg-web-proxy/main/install.sh) \
    --hostname proxy.example.com --email you@example.com --site atlas-books
EOF
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--hostname) hostname="${2:-}"; shift 2 ;;
		--email) email="${2:-}"; shift 2 ;;
		--site) site="${2:-}"; shift 2 ;;
		--secret) secret="${2:-}"; shift 2 ;;
		--dry-run) dry_run=1; shift ;;
		-h|--help) usage; exit 0 ;;
		*) echo "unknown option: $1" >&2; usage; exit 2 ;;
	esac
done

if [[ -z "$hostname" || -z "$email" ]]; then
	usage
	exit 2
fi

if [[ "$(id -u)" -ne 0 ]]; then
	echo "run as root (or: sudo bash install.sh ...)" >&2
	exit 1
fi

if [[ "$(uname -m)" != "x86_64" ]]; then
	echo "official MTProxy backend requires x86_64 Linux" >&2
	exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
	echo "curl is required" >&2
	exit 1
fi

ensure_docker() {
	if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
		return 0
	fi
	echo "Docker not found — installing Docker Engine..."
	if ! command -v apt-get >/dev/null 2>&1; then
		echo "automatic Docker install supports Debian/Ubuntu only; install Docker manually and re-run" >&2
		exit 1
	fi
	export DEBIAN_FRONTEND=noninteractive
	apt-get update
	apt-get install -y --no-install-recommends ca-certificates curl gnupg
	curl -fsSL https://get.docker.com | sh
	if ! docker compose version >/dev/null 2>&1; then
		apt-get install -y --no-install-recommends docker-compose-plugin || true
	fi
	if ! docker compose version >/dev/null 2>&1; then
		echo "docker compose plugin is still missing after install" >&2
		exit 1
	fi
}

ensure_repo() {
	if ! command -v git >/dev/null 2>&1; then
		export DEBIAN_FRONTEND=noninteractive
		apt-get update
		apt-get install -y --no-install-recommends git
	fi
	mkdir -p "$(dirname "$INSTALL_DIR")"
	if [[ -d "$INSTALL_DIR/.git" ]]; then
		git -C "$INSTALL_DIR" fetch origin "$REPO_REF"
		git -C "$INSTALL_DIR" checkout "$REPO_REF"
		git -C "$INSTALL_DIR" pull --ff-only origin "$REPO_REF"
	elif [[ -d "$INSTALL_DIR" ]]; then
		echo "$INSTALL_DIR exists but is not a git checkout; move it aside and re-run" >&2
		exit 1
	else
		git clone --depth 1 --branch "$REPO_REF" "$REPO_URL" "$INSTALL_DIR"
	fi
}

port_busy() {
	port="$1"
	if command -v ss >/dev/null 2>&1; then
		ss -H -ltn "sport = :$port" 2>/dev/null | grep -q .
	elif command -v netstat >/dev/null 2>&1; then
		netstat -ltn 2>/dev/null | awk '{print $4}' | grep -q ":$port\$"
	else
		return 1
	fi
}

if [[ "$dry_run" -eq 1 ]]; then
	echo "[dry-run] would install into $INSTALL_DIR"
	echo "[dry-run] hostname=$hostname email=$email site=$site"
	exit 0
fi

for port in 80 443; do
	if port_busy "$port"; then
		echo "TCP $port is already in use on this host; free it before installing (Caddy needs 80/443)" >&2
		exit 1
	fi
done

ensure_docker
ensure_repo

exec bash "$INSTALL_DIR/scripts/install-docker.sh" --local \
	--hostname "$hostname" \
	--email "$email" \
	--site "$site" \
	${secret:+--secret "$secret"}
