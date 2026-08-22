#!/usr/bin/env bash
# tg-web-proxy · установщик на VPS
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/RTHeLL/tg-web-proxy/main/install.sh)
#
# Можно без флагов — спросит hostname, email и сайт в диалоге.
# Или сразу: --hostname proxy.example.com --email you@example.com --site atlas-books
set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-/opt/tg-web-proxy}"
REPO_URL="${REPO_URL:-https://github.com/RTHeLL/tg-web-proxy.git}"
REPO_REF="${REPO_REF:-main}"

hostname=""
email=""
site=""
secret=""
assume_yes=0
dry_run=0

usage() {
	cat <<'EOF'
tg-web-proxy install

  bash install.sh
  bash install.sh --hostname FQDN --email you@example.com [--site NAME] [--secret HEX] [-y]

  -y, --yes     не спрашивать подтверждение перед установкой
  --dry-run     только показать, что будет сделано
EOF
}

resolve_site_id() {
	case "$1" in
		1|northwind-field) printf '%s' 'northwind-field' ;;
		2|studio-garden) printf '%s' 'studio-garden' ;;
		3|atlas-books) printf '%s' 'atlas-books' ;;
		4|harbor-dental) printf '%s' 'harbor-dental' ;;
		5|craft-roastery) printf '%s' 'craft-roastery' ;;
		6|pixel-repair) printf '%s' 'pixel-repair' ;;
		*) return 1 ;;
	esac
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--hostname) hostname="${2:-}"; shift 2 ;;
		--email) email="${2:-}"; shift 2 ;;
		--site) site="${2:-}"; shift 2 ;;
		--secret) secret="${2:-}"; shift 2 ;;
		-y|--yes) assume_yes=1; shift ;;
		--dry-run) dry_run=1; shift ;;
		-h|--help) usage; exit 0 ;;
		*) echo "неизвестный аргумент: $1" >&2; usage; exit 2 ;;
	esac
done

if [[ -n "$site" ]]; then
	if resolved="$(resolve_site_id "$site")"; then
		site="$resolved"
	fi
fi

UI_SH=""
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/scripts/ui.sh" ]]; then
	UI_SH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scripts/ui.sh"
elif [[ -f "$INSTALL_DIR/scripts/ui.sh" ]]; then
	UI_SH="$INSTALL_DIR/scripts/ui.sh"
fi
if [[ -z "$UI_SH" ]]; then
	UI_TMP_DIR="$(mktemp -d /tmp/tg-web-proxy-ui.XXXXXX)"
	base="https://raw.githubusercontent.com/RTHeLL/tg-web-proxy/${REPO_REF}/scripts"
	if curl -fsSL --proto '=https' --tlsv1.2 "$base/ui.sh" -o "$UI_TMP_DIR/ui.sh" 2>/dev/null; then
		curl -fsSL --proto '=https' --tlsv1.2 "$base/sites.sh" -o "$UI_TMP_DIR/sites.sh" 2>/dev/null || true
		UI_SH="$UI_TMP_DIR/ui.sh"
	fi
fi
if [[ -n "$UI_SH" && -f "$UI_SH" ]]; then
	# shellcheck source=scripts/ui.sh
	source "$UI_SH"
else
	ui_banner() { echo 'tg-web-proxy install'; }
	ui_line() { echo '---'; }
	ui_step() { printf '[%s/%s] %s\n' "$1" "$2" "$3"; }
	ui_ok() { printf 'OK: %s\n' "$1"; }
	ui_warn() { printf 'WARN: %s\n' "$1"; }
	ui_fail() { printf 'ERR: %s\n' "$1" >&2; }
	ui_info() { printf '%s\n' "$1"; }
	ui_box() { shift; while [[ $# -gt 0 ]]; do echo "$1"; shift; done; }
	ui_ask() { local p="$1" d="${2:-}"; [[ -n "$d" ]] && printf '%s [%s]: ' "$p" "$d" || printf '%s: ' "$p"; IFS= read -r r; [[ -z "$r" && -n "$d" ]] && r="$d"; printf '%s' "$r"; }
	ui_ask_yes() { local p="$1"; printf '%s [Y/n]: ' "$p"; IFS= read -r r; [[ -z "$r" || "$r" == y || "$r" == Y || "$r" == да ]]; }
	ui_pick_site() { printf '%s' "${2:-studio-garden}"; }
	ui_spin() { echo "$1"; }
	ui_spin_done() { :; }
	ui_credentials_box() { ui_box 'Готово' "hostname=$1" "secret=$2" "site=$3"; }
fi

normalize_hostname() {
	local h="$1"
	h="${h//$'\r'/}"
	h="${h#"${h%%[![:space:]]*}"}"
	h="${h%"${h##*[![:space:]]}"}"
	h="${h,,}"
	h="${h#https://}"
	h="${h#http://}"
	h="${h%%/*}"
	h="${h%%:*}"
	h="${h%.}"
	printf '%s' "$h"
}

validate_hostname() {
	local h err=""
	h="$(normalize_hostname "$1")"
	[[ -n "$h" ]] || { err='пусто'; printf '%s' "$err"; return 1; }
	[[ "$h" == *.* ]] || { err='нужен домен с точкой, например tweb.kurduk.store'; printf '%s' "$err"; return 1; }
	[[ ${#h} -le 253 ]] || { err='слишком длинный'; printf '%s' "$err"; return 1; }
	[[ "$h" =~ ^[a-z0-9]([a-z0-9-]*(\.[a-z0-9-]+)+)*$ ]] || { err='только a-z, 0-9, дефис и точки; без https:// и слэшей'; printf '%s' "$err"; return 1; }
	printf '%s' "$h"
	return 0
}

validate_email() {
	local e="$1"
	e="${e//$'\r'/}"
	e="${e#"${e%%[![:space:]]*}"}"
	e="${e%"${e##*[![:space:]]}"}"
	[[ "$e" =~ ^[A-Za-z0-9._+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]
}

interactive_setup() {
	ui_banner
	ui_intro
	ui_line

	ui_out "${UI_BOLD}Шаг 1 из 4 · домен для WEB proxy${UI_RESET}\n"
	ui_info 'Тот же hostname, что в DNS A-записи и в Telegram Desktop.'
	ui_info 'Пример: tweb.kurduk.store (без https:// и без :443)'

	while [[ -z "$hostname" ]]; do
		raw="$(ui_ask 'Hostname' '')"
		if normalized="$(validate_hostname "$raw")"; then
			hostname="$normalized"
		else
			ui_warn "$normalized"
			[[ -n "$raw" ]] && ui_info "введено: «${raw}»"
		fi
	done
	ui_ok "hostname: $hostname"

	ui_out "\n${UI_BOLD}Шаг 2 из 4 · email для сертификата${UI_RESET}\n"
	ui_info 'Let'\''s Encrypt пришлёт уведомления сюда, если что-то пойдёт не так.'

	while [[ -z "$email" ]]; do
		email="$(ui_ask 'Email' '')"
		email="${email//$'\r'/}"
		if ! validate_email "$email"; then
			ui_warn 'нужен нормальный email, например admin@kurduk.store'
			email=""
		fi
	done
	ui_ok "email: $email"

	ui_info 'Шаблон сайта выберем после загрузки кода (шаг 3 из 5).'

	ui_out "\n${UI_BOLD}Шаг 3 из 4 · ключ${UI_RESET}\n"
	if [[ -z "$secret" ]]; then
		if ui_ask_yes 'Сгенерировать ключ автоматически?' 'y'; then
			secret=""
		else
			while true; do
				secret="$(ui_ask 'Ключ (32 hex, dd в начале — по желанию)' '')"
				secret="${secret,,}"
				if [[ "$secret" =~ ^([0-9a-f]{32}|dd[0-9a-f]{32})$ ]]; then
					break
				fi
				ui_warn 'нужно ровно 32 hex-символа'
				secret=""
			done
		fi
	fi

	ui_line
	ui_box 'Проверь и жми Enter для старта' \
		"Hostname : $hostname" \
		"Email    : $email" \
		"Site     : ${site:-выбор после git clone}" \
		"Каталог  : $INSTALL_DIR"

	if [[ "$assume_yes" -eq 0 ]]; then
		if ! ui_ask_yes 'Начать установку?' 'y'; then
			ui_warn 'отменено'
			exit 0
		fi
	fi
}

preflight() {
	if [[ "$(id -u)" -ne 0 ]]; then
		ui_fail 'запускай от root: sudo bash install.sh'
		exit 1
	fi
	if [[ "$(uname -m)" != "x86_64" ]]; then
		ui_fail 'нужен x86_64 — так собран MTProxy внутри образа'
		exit 1
	fi
	if ! command -v curl >/dev/null 2>&1; then
		ui_fail 'нужен curl'
		exit 1
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

ensure_docker() {
	ui_step 2 5 'Docker'
	if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
		ui_ok "$(docker --version | head -1)"
		return 0
	fi
	ui_warn 'docker не найден — ставлю через get.docker.com'
	if ! command -v apt-get >/dev/null 2>&1; then
		ui_fail 'автоустановка только для Debian/Ubuntu; docker поставь руками'
		exit 1
	fi
	ui_spin 'ставлю docker'
	export DEBIAN_FRONTEND=noninteractive
	apt-get update -qq
	apt-get install -y -qq --no-install-recommends ca-certificates curl gnupg
	curl -fsSL https://get.docker.com | sh
	if ! docker compose version >/dev/null 2>&1; then
		apt-get install -y -qq --no-install-recommends docker-compose-plugin || true
	fi
	ui_spin_done
	if ! docker compose version >/dev/null 2>&1; then
		ui_fail 'compose так и не появился'
		exit 1
	fi
	ui_ok 'docker готов'
}

ensure_repo() {
	ui_step 3 5 'Код'
	if ! command -v git >/dev/null 2>&1; then
		export DEBIAN_FRONTEND=noninteractive
		apt-get update -qq
		apt-get install -y -qq --no-install-recommends git
	fi
	mkdir -p "$(dirname "$INSTALL_DIR")"
	ui_spin "git → $INSTALL_DIR"
	if [[ -d "$INSTALL_DIR/.git" ]]; then
		git -C "$INSTALL_DIR" fetch origin "$REPO_REF" -q
		git -C "$INSTALL_DIR" checkout "$REPO_REF" -q
		git -C "$INSTALL_DIR" pull --ff-only origin "$REPO_REF" -q
	elif [[ -d "$INSTALL_DIR" ]]; then
		ui_spin_done
		ui_fail "$INSTALL_DIR есть, но это не git — убери каталог или переименуй"
		exit 1
	else
		git clone --depth 1 --branch "$REPO_REF" "$REPO_URL" "$INSTALL_DIR" -q
	fi
	ui_spin_done
	ui_ok "$INSTALL_DIR"
	# shellcheck source=scripts/ui.sh
	if [[ -f "$INSTALL_DIR/scripts/ui.sh" ]]; then
		source "$INSTALL_DIR/scripts/ui.sh"
	fi
}

deploy_stack() {
	ui_step 4 5 'Сборка и запуск'
	args=(--local --hostname "$hostname" --email "$email" --site "$site")
	[[ -n "$secret" ]] && args+=(--secret "$secret")
	bash "$INSTALL_DIR/scripts/install-docker.sh" "${args[@]}"
}

preflight

if [[ -z "$hostname" || -z "$email" ]]; then
	interactive_setup
else
	ui_banner
	if [[ -z "$site" ]]; then
		site="studio-garden"
	fi
	if [[ "$assume_yes" -eq 0 ]] && ui_is_tty; then
		ui_box 'Параметры' \
			"Hostname : $hostname" \
			"Email    : $email" \
			"Site     : $site"
		ui_ask_yes 'Продолжить?' 'y' || exit 0
	fi
fi

if normalized="$(validate_hostname "$hostname")"; then
	hostname="$normalized"
else
	ui_fail "$normalized"
	exit 2
fi
if ! validate_email "$email"; then
	ui_fail 'email не прошёл проверку'
	exit 2
fi

if [[ "$dry_run" -eq 1 ]]; then
	ui_box 'dry-run' \
		"hostname=$hostname" \
		"email=$email" \
		"site=${site:-studio-garden}" \
		"dir=$INSTALL_DIR"
	exit 0
fi

ui_step 1 5 'Порты 80/443'
for port in 80 443; do
	if port_busy "$port"; then
		ui_fail "порт $port занят — освободи nginx/apache/caddy на хосте"
		exit 1
	fi
done
ui_ok 'свободны'

ensure_docker
ensure_repo

if [[ -z "$site" ]]; then
	ui_out "\n${UI_BOLD}Шаг 4 из 5 · сайт на вашем домене${UI_RESET}\n"
	site="$(ui_pick_site "$INSTALL_DIR" "speedtest")"
	ui_ok "site: $site"
fi

deploy_stack
