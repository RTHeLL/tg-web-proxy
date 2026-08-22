#!/usr/bin/env bash
# Full automatic WEB Proxy deployment via Docker Compose.
#
# Prefer the one-liner installer on the VPS:
#   bash <(curl -fsSL https://raw.githubusercontent.com/RTHeLL/tg-web-proxy/main/install.sh) \
#     --hostname proxy.example.com --email you@example.com --site craft-roastery
#
# Or run locally from a git checkout:
#   bash scripts/install-docker.sh --local \
#     --hostname proxy.example.com --email you@example.com --site atlas-books
#
# List sites: bash scripts/list-sites.sh
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mode=""
ssh_target=""
hostname=""
email=""
site=""
secret=""
remote_dir="/opt/tg-web-proxy"
dry_run=0

usage() {
	cat <<'EOF'
usage:
  install-docker.sh --ssh user@host --hostname FQDN --email addr --site NAME [--secret HEX] [--remote-dir PATH]
  install-docker.sh --local  --hostname FQDN --email addr --site NAME [--secret HEX]

options:
  --secret       32 hex chars, optional dd prefix (generated if omitted)
  --remote-dir   install path on VPS (default: /opt/tg-web-proxy)
  --dry-run      print actions without executing remote/local docker steps
EOF
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--local) mode=local; shift ;;
		--ssh) ssh_target="${2:-}"; mode=remote; shift 2 ;;
		--hostname) hostname="${2:-}"; shift 2 ;;
		--email) email="${2:-}"; shift 2 ;;
		--site) site="${2:-}"; shift 2 ;;
		--secret) secret="${2:-}"; shift 2 ;;
		--remote-dir) remote_dir="${2:-}"; shift 2 ;;
		--dry-run) dry_run=1; shift ;;
		-h|--help) usage; exit 0 ;;
		*) usage; exit 2 ;;
	esac
done

if [[ -z "$mode" || -z "$hostname" || -z "$email" || -z "$site" ]]; then
	usage
	exit 2
fi

if [[ ! "$hostname" =~ ^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$ ]] || [[ "$hostname" != *.* ]]; then
	echo "hostname must be lowercase ASCII DNS" >&2
	exit 2
fi
if [[ ! "$email" =~ ^[A-Za-z0-9._+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
	echo "invalid email" >&2
	exit 2
fi
site_dir="$root/web/sites/$site"
if [[ ! -f "$site_dir/index.html" ]]; then
	echo "unknown site variant: $site" >&2
	echo "available:" >&2
	bash "$root/scripts/list-sites.sh" >&2
	exit 2
fi

if [[ -z "$secret" ]]; then
	secret="$(bash "$root/scripts/gen-secret.sh")"
fi
if [[ ! "$secret" =~ ^([0-9a-f]{32}|dd[0-9a-f]{32})$ ]]; then
	echo "secret must be 32 lowercase hex chars, optionally prefixed with dd" >&2
	exit 2
fi

prepare_runtime() {
	target_root="$1"
	mkdir -p "$target_root/runtime/site"
	if command -v rsync >/dev/null 2>&1; then
		rsync -a --delete "$site_dir/" "$target_root/runtime/site/"
	else
		find "$target_root/runtime/site" -mindepth 1 -delete 2>/dev/null || rm -rf "$target_root/runtime/site"/*
		cp -a "$site_dir/." "$target_root/runtime/site/"
	fi
	cat >"$target_root/.env" <<EOF
TPROXY_HOSTNAME=$hostname
ACME_EMAIL=$email
TPROXY_SECRET=$secret
SITE_VARIANT=$site
MTPROXY_WORKERS=1
MTPROXY_MAX_CONNECTIONS=4096
EOF
	chmod 0600 "$target_root/.env"
}

check_docker() {
	if ! command -v docker >/dev/null 2>&1; then
		echo "docker is not installed" >&2
		return 1
	fi
	if ! docker compose version >/dev/null 2>&1; then
		echo "docker compose plugin is not available" >&2
		return 1
	fi
}

deploy_compose() {
	workdir="$1"
	cd "$workdir"
	docker compose --env-file .env build
	docker compose --env-file .env up -d
	for attempt in $(seq 1 60); do
		if docker compose exec -T tproxy curl --fail --silent http://127.0.0.1:8081/readyz >/dev/null 2>&1; then
			return 0
		fi
		sleep 2
	done
	echo "stack did not become ready in time" >&2
	docker compose logs --tail=80 tproxy || true
	return 1
}

print_summary() {
	cat <<EOF

Deployment complete.

  Hostname : $hostname
  Secret   : $secret
  Site     : $site

Telegram Desktop → WEB proxy:
  Hostname : $hostname
  Key      : $secret

Share link (PoC):
  tg://webproxy?server=$hostname&secret=$secret

Checks:
  curl --fail https://$hostname/
  docker compose ps
  docker compose logs -f tproxy

EOF
}

if [[ "$mode" == "local" ]]; then
	prepare_runtime "$root"
	if [[ "$dry_run" -eq 1 ]]; then
		echo "[dry-run] prepared $root/.env and runtime/site ($site)"
		exit 0
	fi
	check_docker
	deploy_compose "$root"
	print_summary
	exit 0
fi

if [[ "$dry_run" -eq 1 ]]; then
	echo "[dry-run] would rsync to $ssh_target:$remote_dir and run docker compose"
	exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
rsync -a --delete \
	--exclude .git \
	--exclude runtime \
	--exclude .deploy \
	"$root/" "$tmp/project/"
prepare_runtime "$tmp/project"

ssh "$ssh_target" "mkdir -p '$remote_dir'"
rsync -az --delete \
	"$tmp/project/" "$ssh_target:$remote_dir/"

if ! ssh "$ssh_target" "command -v docker >/dev/null && docker compose version >/dev/null"; then
	cat <<EOF >&2
Docker is not available on $ssh_target.

On the VPS you still need (one-time, on the host — not inside this repo):
  - Docker Engine + Compose plugin
  - open TCP 80/443
  - DNS A record: $hostname -> server IP (no CDN)

After installing Docker, re-run the same install-docker.sh command.
Optional helper (run manually on VPS if you agree):
  curl -fsSL https://get.docker.com | sh
EOF
	exit 1
fi

ssh "$ssh_target" "cd '$remote_dir' && docker compose --env-file .env build && docker compose --env-file .env up -d"

ready=0
for attempt in $(seq 1 60); do
	if ssh "$ssh_target" "cd '$remote_dir' && docker compose exec -T tproxy curl --fail --silent http://127.0.0.1:8081/readyz" >/dev/null 2>&1; then
		ready=1
		break
	fi
	sleep 2
done
if [[ "$ready" -ne 1 ]]; then
	echo "remote stack did not become ready; inspect: ssh $ssh_target 'cd $remote_dir && docker compose logs tproxy'" >&2
	exit 1
fi

print_summary
