#!/bin/sh
set -eu

log() {
	printf '[entrypoint] %s\n' "$1" >&2
}

require_env() {
	var="$1"
	eval "value=\${$var:-}"
	if [ -z "$value" ]; then
		echo "missing required env: $var" >&2
		exit 1
	fi
}

require_env TPROXY_HOSTNAME
require_env ACME_EMAIL
require_env TPROXY_SECRET

: "${CARRIER_MODE:=websocket}"
: "${BACKEND:=telemt}"
export CARRIER_MODE BACKEND

mkdir -p /etc/mtproxy /etc/tproxy-server /etc/caddy /etc/telemt /srv/tproxy-site

backend_secret="$TPROXY_SECRET"
telemt_classic=true
telemt_secure=false
case "$backend_secret" in
	dd*)
		backend_secret="${backend_secret#dd}"
		telemt_classic=false
		telemt_secure=true
		;;
esac

write_telemt_config() {
	sed \
		-e "s/__TELEMT_CLASSIC__/${telemt_classic}/" \
		-e "s/__TELEMT_SECURE__/${telemt_secure}/" \
		-e "s/__TPROXY_SECRET_HEX__/${backend_secret}/" \
		/etc/telemt/telemt.template.toml > /etc/telemt/telemt.toml
	chmod 0640 /etc/telemt/telemt.toml
}

wait_tcp() {
	host="$1"
	port="$2"
	attempts="${3:-90}"
	i=0
	while [ "$i" -lt "$attempts" ]; do
		if nc -z "$host" "$port" 2>/dev/null; then
			return 0
		fi
		i=$((i + 1))
		sleep 1
	done
	return 1
}

start_mtproxy() {
	if [ ! -f /etc/mtproxy/proxy-secret ]; then
		log "downloading MTProxy secret"
		curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 \
			--output /etc/mtproxy/proxy-secret https://core.telegram.org/getProxySecret
	fi
	if [ ! -f /etc/mtproxy/proxy-multi.conf ]; then
		log "downloading MTProxy config"
		curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 \
			--output /etc/mtproxy/proxy-multi.conf https://core.telegram.org/getProxyConfig
	fi
	chmod 0640 /etc/mtproxy/proxy-secret /etc/mtproxy/proxy-multi.conf

	log "starting MTProxy backend (official)"
	/usr/local/bin/mtproto-proxy \
		-u nobody \
		-p 8888 \
		-H 2398 \
		-S "$backend_secret" \
		--aes-pwd /etc/mtproxy/proxy-secret \
		/etc/mtproxy/proxy-multi.conf \
		-M "${MTPROXY_WORKERS:-1}" \
		-C "${MTPROXY_MAX_CONNECTIONS:-4096}" &
	backend_pid=$!
}

start_telemt() {
	write_telemt_config
	log "starting telemt backend on 127.0.0.1:2398"
	/usr/local/bin/telemt /etc/telemt/telemt.toml &
	backend_pid=$!
}

export TPROXY_HOSTNAME ACME_EMAIL TPROXY_SECRET
mkdir -p /data/caddy
export XDG_DATA_HOME=/data/caddy
export XDG_CONFIG_HOME=/data/caddy
envsubst '${TPROXY_HOSTNAME} ${TPROXY_SECRET}' \
	< /etc/tproxy-server/config.template.json > /etc/tproxy-server/config.json
envsubst '${TPROXY_SECRET} ${CARRIER_MODE}' \
	< /etc/tproxy-server/profiles.template.json > /etc/tproxy-server/profiles.json
chmod 0640 /etc/tproxy-server/config.json
chmod 0400 /etc/tproxy-server/profiles.json

/usr/local/bin/tproxy-server \
	-config /etc/tproxy-server/config.json \
	-profiles-file /etc/tproxy-server/profiles.json \
	-check

backend_pid=0
case "$BACKEND" in
	telemt) start_telemt ;;
	mtproxy|official|*) start_mtproxy ;;
esac

log "waiting for backend on 127.0.0.1:2398"
if ! wait_tcp 127.0.0.1 2398 90; then
	echo "backend did not open 127.0.0.1:2398" >&2
	exit 1
fi
log "backend is listening on :2398"

log "starting tproxy-server relay"
/usr/local/bin/tproxy-server \
	-config /etc/tproxy-server/config.json \
	-profiles-file /etc/tproxy-server/profiles.json &
relay_pid=$!

ready=0
i=0
while [ "$i" -lt 30 ]; do
	if curl --fail --silent --output /dev/null http://127.0.0.1:8081/readyz; then
		ready=1
		break
	fi
	i=$((i + 1))
	sleep 1
done
if [ "$ready" -ne 1 ]; then
	echo "tproxy-server did not become ready" >&2
	exit 1
fi
log "relay ready on :8080/:8081"

cleanup() {
	log "shutting down"
	kill "$relay_pid" "$backend_pid" 2>/dev/null || true
	wait "$relay_pid" "$backend_pid" 2>/dev/null || true
}
trap cleanup INT TERM

log "starting Caddy on :80/:443 for https://${TPROXY_HOSTNAME}/ (backend=${BACKEND})"
exec /usr/local/bin/caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
