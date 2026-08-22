#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/ui.sh
source "$root/scripts/ui.sh"

mode=""
ssh_target=""
hostname=""
email=""
site=""
secret=""
remote_dir="/opt/tg-web-proxy"
dry_run=0
quiet=0

usage() {
	cat <<'EOF'
install-docker.sh --local --hostname FQDN --email addr --site NAME [--secret HEX]
install-docker.sh --ssh user@host --hostname FQDN --email addr --site NAME
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
		-q|--quiet) quiet=1; shift ;;
		-h|--help) usage; exit 0 ;;
		*) usage; exit 2 ;;
	esac
done

if [[ -z "$mode" || -z "$hostname" || -z "$email" || -z "$site" ]]; then
	usage
	exit 2
fi

if [[ ! "$hostname" =~ ^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$ ]] || [[ "$hostname" != *.* ]]; then
	ui_fail 'hostname: только fqdn маленькими буквами'
	exit 2
fi
if [[ ! "$email" =~ ^[A-Za-z0-9._+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
	ui_fail 'кривой email'
	exit 2
fi
site_dir="$root/web/sites/$site"
if [[ ! -f "$site_dir/index.html" ]]; then
	ui_fail "нет такого сайта: $site"
	bash "$root/scripts/list-sites.sh" >&2
	exit 2
fi

if [[ -z "$secret" ]]; then
	ui_spin 'генерирую ключ'
	secret="$(bash "$root/scripts/gen-secret.sh")"
	ui_spin_done
	ui_ok "ключ: ${secret:0:8}…${secret: -4}"
fi
if [[ ! "$secret" =~ ^([0-9a-f]{32}|dd[0-9a-f]{32})$ ]]; then
	ui_fail 'secret: 32 hex, dd в начале — по желанию'
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
CARRIER_MODE=websocket
BACKEND=telemt
TELEMT_MIDDLE_PROXY=false
MTPROXY_WORKERS=1
MTPROXY_MAX_CONNECTIONS=4096
EOF
	chmod 0600 "$target_root/.env"
}

check_docker() {
	if ! command -v docker >/dev/null 2>&1; then
		ui_fail 'docker не установлен'
		return 1
	fi
	if ! docker compose version >/dev/null 2>&1; then
		ui_fail 'нет docker compose plugin'
		return 1
	fi
}

deploy_compose() {
	workdir="$1"
	cd "$workdir"
	ui_step 5 5 'docker compose'
	ui_spin 'собираю образ (первый раз может занять несколько минут)'
	docker compose --env-file .env build
	ui_spin_done
	ui_ok 'образ собран'
	ui_spin 'поднимаю контейнер'
	docker compose --env-file .env up -d
	ui_spin_done
	ui_spin 'жду readyz'
	for attempt in $(seq 1 60); do
		if docker compose exec -T tproxy curl --fail --silent http://127.0.0.1:8081/readyz >/dev/null 2>&1; then
			ui_spin_done
			ui_ok 'релей отвечает'
			return 0
		fi
		sleep 2
	done
	ui_spin_done
	ui_fail 'таймаут — смотри docker compose logs tproxy'
	docker compose logs --tail=80 tproxy || true
	return 1
}

print_summary() {
	ui_credentials_box "$hostname" "$secret" "$site" "$root"
}

install_system_cli() {
	if [[ "$(id -u)" -ne 0 ]]; then
		return 0
	fi
	bash "$root/scripts/tgwebpr" _install_cli "$root"
	ui_ok 'команда tgwebpr → /usr/local/bin/tgwebpr'
}

if [[ "$mode" == "local" ]]; then
	if [[ "$quiet" -eq 0 ]]; then
		ui_info "сайт: $site → runtime/site/"
	fi
	prepare_runtime "$root"
	if [[ "$dry_run" -eq 1 ]]; then
		ui_box 'dry-run' "готово $root/.env"
		exit 0
	fi
	check_docker
	deploy_compose "$root"
	install_system_cli
	print_summary
	exit 0
fi

if [[ "$dry_run" -eq 1 ]]; then
	ui_box 'dry-run' "rsync → $ssh_target:$remote_dir"
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
	ui_fail "на $ssh_target нет docker compose"
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
	ui_fail "не дождался readyz на $ssh_target"
	exit 1
fi

print_summary
