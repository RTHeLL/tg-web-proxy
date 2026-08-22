#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
	echo "run this updater as root from the uploaded repository" >&2
	exit 1
fi

repository="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
installed=/usr/local/bin/tproxy-server
next=/usr/local/bin/tproxy-server.next
previous=/usr/local/bin/tproxy-server.previous
config=/etc/tproxy-server/config.json
profiles=/etc/tproxy-server/profiles.json
service=tproxy-server.service
health=http://127.0.0.1:8081/healthz
ready=http://127.0.0.1:8081/readyz
temporary="$(mktemp -d /tmp/tproxy-server-update.XXXXXX)"
candidate="$temporary/tproxy-server"
trap 'rm -rf -- "$temporary"' EXIT

for required in "$installed" "$config" "$profiles"; do
	if [[ ! -f "$required" ]]; then
		echo "missing installed deployment file: $required" >&2
		exit 1
	fi
done
for required_command in curl flock install systemctl; do
	if ! command -v "$required_command" >/dev/null 2>&1; then
		echo "$required_command is required" >&2
		exit 1
	fi
done
exec 9>/run/lock/tproxy-server-update.lock
if ! flock -n 9; then
	echo "another relay update is already running" >&2
	exit 1
fi

go_binary=
go_candidates=()
if command -v go >/dev/null 2>&1; then
	go_candidates+=("$(command -v go)")
fi
for found in /opt/go*/bin/go; do
	go_candidates+=("$found")
done
for found in "${go_candidates[@]}"; do
	if [[ ! -x "$found" ]]; then
		continue
	fi
	version="$("$found" env GOVERSION 2>/dev/null || true)"
	if [[ "$version" =~ ^go1\.([0-9]+) ]] && (( BASH_REMATCH[1] >= 20 )); then
		go_binary="$found"
		break
	fi
done
if [[ -z "$go_binary" ]]; then
	echo "Go 1.20 or newer was not found in PATH or /opt/go*/bin/go" >&2
	exit 1
fi

wait_for() {
	local url="$1"
	for ((attempt = 0; attempt != 20; ++attempt)); do
		if curl --fail --silent --output /dev/null "$url"; then
			return 0
		fi
		sleep 1
	done
	return 1
}

rollback() {
	echo "New relay failed verification; restoring $previous" >&2
	install -o root -g root -m 0755 "$previous" "$next"
	mv -f "$next" "$installed"
	if ! systemctl restart "$service" || ! wait_for "$health"; then
		echo "Rollback failed; inspect: journalctl -u $service -n 100 --no-pager" >&2
		return 1
	fi
	echo "Previous relay restored and healthy" >&2
}

was_ready=
if curl --fail --silent --output /dev/null "$ready"; then
	was_ready=1
fi

echo "Testing relay source"
(cd "$repository" && "$go_binary" test ./...)

echo "Building relay candidate with $go_binary"
(cd "$repository" && "$go_binary" build \
	-trimpath -ldflags='-s -w' -o "$candidate" ./cmd/tproxy-server)

echo "Validating candidate against the installed configuration"
"$candidate" -config "$config" -profiles-file "$profiles" -check

echo "Installing relay candidate"
backup_next="$temporary/tproxy-server.previous"
cp -a "$installed" "$backup_next"
install -o root -g root -m 0755 "$backup_next" "$previous"
install -o root -g root -m 0755 "$candidate" "$next"
mv -f "$next" "$installed"

echo "Restarting only $service"
if ! systemctl restart "$service" || ! wait_for "$health"; then
	rollback
	exit 1
fi
if [[ -n "$was_ready" ]] && ! wait_for "$ready"; then
	rollback
	exit 1
fi

echo "Relay update complete"
if curl --fail --silent --output /dev/null "$ready"; then
	echo "Health: ok; readiness: ok"
else
	echo "Health: ok; readiness: backend unavailable (unchanged from before update)"
fi
echo "Existing carrier sessions were invalidated; the hidden WebView will reconnect automatically."
