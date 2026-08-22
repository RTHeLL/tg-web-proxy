#!/usr/bin/env bash
# Terminal UI helpers for tg-web-proxy installers.
# Source from install scripts; safe when stdout is not a TTY.

ui_is_tty() {
	[[ -t 1 ]] && [[ -t 0 ]]
}

# curl | bash и bash <(curl ...) не дают read-у доступ к клавиатуре — только /dev/tty
ui_can_prompt() {
	[[ -r /dev/tty && -w /dev/tty ]]
}

ui_out() {
	if ui_can_prompt && ! ui_is_tty; then
		printf '%b' "$1" >/dev/tty
	else
		printf '%b' "$1"
	fi
}

if ui_is_tty; then
	UI_RESET=$'\033[0m'
	UI_BOLD=$'\033[1m'
	UI_DIM=$'\033[2m'
	UI_CYAN=$'\033[36m'
	UI_GREEN=$'\033[32m'
	UI_YELLOW=$'\033[33m'
	UI_RED=$'\033[31m'
	UI_BLUE=$'\033[34m'
	UI_MAG=$'\033[35m'
else
	UI_RESET='' UI_BOLD='' UI_DIM='' UI_CYAN='' UI_GREEN=''
	UI_YELLOW='' UI_RED='' UI_BLUE='' UI_MAG=''
fi

ui_banner() {
	ui_out "${UI_CYAN}${UI_BOLD}
  ┌──────────────────────────────────────────────┐
  │           tg-web-proxy installer             │
  │     Telegram Desktop · WEB · Docker          │
  └──────────────────────────────────────────────┘
${UI_RESET}${UI_DIM}  github.com/RTHeLL/tg-web-proxy${UI_RESET}
"
}

ui_intro() {
	ui_info 'Перед установкой: DNS A-запись домена → IP этого сервера.'
	ui_info 'Порты 80 и 443 должны быть свободны (nginx/caddy на хосте — выключить).'
}

ui_line() {
	ui_out "${UI_DIM}────────────────────────────────────────────────${UI_RESET}\n"
}

ui_step() {
	ui_out "\n${UI_BLUE}[${1}/${2}]${UI_RESET} ${3}\n"
}

ui_ok() {
	ui_out "  ${UI_GREEN}✓${UI_RESET} ${1}\n"
}

ui_warn() {
	ui_out "  ${UI_YELLOW}!${UI_RESET} ${1}\n"
}

ui_fail() {
	ui_out "  ${UI_RED}✗${UI_RESET} ${1}\n" >&2
}

ui_info() {
	ui_out "  ${UI_DIM}·${UI_RESET} ${1}\n"
}

ui_box() {
	title="$1"
	shift
	ui_line
	ui_out "${UI_BOLD}${title}${UI_RESET}\n"
	while [[ $# -gt 0 ]]; do
		ui_out "  ${1}\n"
		shift
	done
	ui_line
}

ui_spin() {
	msg="$1"
	if ! ui_is_tty; then
		printf '  … %s\n' "$msg"
		return 0
	fi
	printf '  %s…%s %s' "$UI_DIM" "$UI_RESET" "$msg"
	(
		chars='|/-\'
		i=0
		while kill -0 "$PPID" 2>/dev/null; do
			c="${chars:i%${#chars}:1}"
			printf '\r  %s%s%s %s' "$UI_DIM" "$c" "$UI_RESET" "$msg"
			i=$((i + 1))
			sleep 0.12
		done
	) &
	UI_SPIN_PID=$!
}

ui_spin_done() {
	if [[ -n "${UI_SPIN_PID:-}" ]]; then
		kill "$UI_SPIN_PID" 2>/dev/null || true
		wait "$UI_SPIN_PID" 2>/dev/null || true
		unset UI_SPIN_PID
	fi
	if ui_is_tty; then
		printf '\r\033[K'
	fi
}

ui_read_line() {
	reply=""
	if ui_can_prompt; then
		IFS= read -r reply < /dev/tty || reply=""
	else
		IFS= read -r reply || reply=""
	fi
	printf '%s' "$reply"
}

ui_ask() {
	prompt="$1"
	default="${2:-}"
	if [[ -n "$default" ]]; then
		ui_out "${UI_BOLD}${prompt}${UI_RESET} [${default}]: "
	else
		ui_out "${UI_BOLD}${prompt}${UI_RESET}: "
	fi
	reply="$(ui_read_line)"
	if [[ -z "$reply" && -n "$default" ]]; then
		reply="$default"
	fi
	printf '%s' "$reply"
}

ui_ask_yes() {
	prompt="$1"
	default="${2:-y}"
	if [[ "$default" == "y" ]]; then
		hint='Y/n'
	else
		hint='y/N'
	fi
	ui_out "${UI_BOLD}${prompt}${UI_RESET} (${hint}): "
	reply="$(ui_read_line)"
	reply="$(printf '%s' "$reply" | tr '[:upper:]' '[:lower:]')"
	if [[ -z "$reply" ]]; then
		reply="$default"
	fi
	[[ "$reply" == "y" || "$reply" == "yes" || "$reply" == "д" || "$reply" == "да" ]]
}

ui_pick_site() {
	root="$1"
	selected="${2:-}"

	if [[ -n "$selected" ]]; then
		printf '%s' "$selected"
		return 0
	fi

	# порядок и подписи фиксированы — меню не зависит от того, клонирован ли уже репо
	site_ids=(northwind-field studio-garden atlas-books harbor-dental craft-roastery pixel-repair)
	site_labels=(
		'Northwind Field Notes — полевые заметки'
		'Studio Garden — ландшафт'
		'Atlas Books — книжный'
		'Harbor Dental — стоматология'
		'Craft Roastery — кофе'
		'Pixel Repair — ремонт техники'
	)

	ui_line
	ui_out "${UI_BOLD}Шаг 3 из 4 · сайт на вашем домене${UI_RESET}\n"
	ui_info 'По адресу https://ваш-домен/ откроется обычная страница (книжный, кофейня и т.п.).'
	ui_info 'Это только обложка. Прокси работает независимо от текста на сайте.'
	ui_info 'Enter = пункт 2'
	ui_out '\n'

	i=1
	for label in "${site_labels[@]}"; do
		id="${site_ids[$((i - 1))]}"
		ui_out "  ${UI_CYAN}${i})${UI_RESET}  ${label}\n"
		i=$((i + 1))
	done

	ui_out '\n'
	while true; do
		choice="$(ui_ask 'Номер пункта' '2')"
		if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#site_ids[@]} )); then
			printf '%s' "${site_ids[$((choice - 1))]}"
			return 0
		fi
		for id in "${site_ids[@]}"; do
			if [[ "$choice" == "$id" ]]; then
				printf '%s' "$id"
				return 0
			fi
		done
		ui_warn 'введи номер из списка (1–6)'
	done
}

ui_credentials_box() {
	hostname="$1"
	secret="$2"
	site="$3"
	install_dir="${4:-/opt/tg-web-proxy}"

	ui_box 'Готово' \
		"Hostname : $hostname" \
		"Key      : $secret" \
		"Site     : $site" \
		"" \
		"Telegram Desktop → WEB → hostname + key" \
		"tg://webproxy?server=${hostname}&secret=${secret}" \
		"" \
		"Дальше: tgwebpr          — меню управления" \
		"        tgwebpr creds    — снова показать key" \
		"        tgwebpr status   — проверить состояние"
}
