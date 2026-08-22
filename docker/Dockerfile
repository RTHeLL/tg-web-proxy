FROM debian:bookworm-slim AS mtproxy-builder
ARG MTPROXY_COMMIT=f36d8af769ffaeac36978d38c2c0f6d1104c2137
ARG MTPROXY_SHA256=919795c416b870670841a21d1930ad97a24c7b84b9eb8c6f9e3de32f2fdf4655
RUN apt-get update \
	&& apt-get install -y --no-install-recommends ca-certificates curl build-essential libssl-dev zlib1g-dev \
	&& rm -rf /var/lib/apt/lists/*
WORKDIR /build
RUN curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 \
		--output MTProxy.tar.gz "https://github.com/TelegramMessenger/MTProxy/archive/${MTPROXY_COMMIT}.tar.gz" \
	&& echo "${MTPROXY_SHA256}  MTProxy.tar.gz" | sha256sum -c \
	&& tar --strip-components=1 -xzf MTProxy.tar.gz \
	&& make -j"$(nproc)" \
	&& test -x objs/bin/mtproto-proxy

FROM golang:1.23-bookworm AS tproxy-builder
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY cmd/ ./cmd/
COPY internal/ ./internal/
RUN CGO_ENABLED=0 go test ./... \
	&& CGO_ENABLED=0 go build -trimpath -ldflags='-s -w' -o /tproxy-server ./cmd/tproxy-server

FROM debian:bookworm-slim
ARG CADDY_VERSION=2.11.4
ARG CADDY_SHA512=8220d1f013b6f27510247b2360c9e0ca9f018feebd82515f07635318b34ff9777ccc8fd0b6e6f2486ce3a33fe389fbb7db12d05baa474f4587509fb4f5ebf1c9
ARG TELEMT_VERSION=3.5.0
ARG TELEMT_SHA256=68849c4c885a017ef8d783937e2e96d2910567d49703dde4c9b6c544e374bf74
RUN apt-get update \
	&& apt-get install -y --no-install-recommends ca-certificates curl gettext-base \
	&& rm -rf /var/lib/apt/lists/*
RUN curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 \
		--output /tmp/caddy.tar.gz "https://github.com/caddyserver/caddy/releases/download/v${CADDY_VERSION}/caddy_${CADDY_VERSION}_linux_amd64.tar.gz" \
	&& echo "${CADDY_SHA512}  /tmp/caddy.tar.gz" | sha512sum -c \
	&& tar -C /usr/local/bin -xzf /tmp/caddy.tar.gz caddy \
	&& rm -f /tmp/caddy.tar.gz
RUN curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 \
		--output /tmp/telemt.tar.gz "https://github.com/telemt/telemt/releases/download/v${TELEMT_VERSION}/telemt-x86_64-linux-gnu.tar.gz" \
	&& echo "${TELEMT_SHA256}  /tmp/telemt.tar.gz" | sha256sum -c \
	&& tar -C /usr/local/bin -xzf /tmp/telemt.tar.gz telemt \
	&& rm -f /tmp/telemt.tar.gz \
	&& chmod 0755 /usr/local/bin/telemt
COPY --from=mtproxy-builder /build/objs/bin/mtproto-proxy /usr/local/bin/mtproto-proxy
COPY --from=tproxy-builder /tproxy-server /usr/local/bin/tproxy-server
COPY docker/Caddyfile /etc/caddy/Caddyfile
COPY docker/config.template.json /etc/tproxy-server/config.template.json
COPY docker/profiles.template.json /etc/tproxy-server/profiles.template.json
COPY docker/telemt.template.toml /etc/telemt/telemt.template.toml
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod 0755 /entrypoint.sh /usr/local/bin/mtproto-proxy /usr/local/bin/tproxy-server /usr/local/bin/telemt /usr/local/bin/caddy
VOLUME ["/data/caddy", "/srv/tproxy-site"]
EXPOSE 80 443
ENV MTPROXY_WORKERS=1 MTPROXY_MAX_CONNECTIONS=4096 BACKEND=telemt
ENTRYPOINT ["/entrypoint.sh"]
