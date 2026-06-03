#!/usr/bin/env bash
set -euo pipefail

DOMAIN="${DOMAIN:-ai.ombhrum.com}"
LIBRECHAT_DIR="${LIBRECHAT_DIR:-/opt/librechat/current}"
LIBRECHAT_REPO="${LIBRECHAT_REPO:-https://github.com/danny-avila/LibreChat.git}"
LIBRECHAT_REF="${LIBRECHAT_REF:-main}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root or with sudo." >&2
  exit 1
fi

apt-get update
apt-get install -y ca-certificates curl git gnupg lsb-release

if ! command -v docker >/dev/null 2>&1; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  . /etc/os-release
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

if ! command -v caddy >/dev/null 2>&1; then
  apt-get install -y debian-keyring debian-archive-keyring apt-transport-https
  curl -1sLf https://dl.cloudsmith.io/public/caddy/stable/gpg.key \
    | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  curl -1sLf https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt \
    > /etc/apt/sources.list.d/caddy-stable.list
  apt-get update
  apt-get install -y caddy
fi

install -d -m 0755 "$(dirname "$LIBRECHAT_DIR")"
if [[ ! -d "$LIBRECHAT_DIR/.git" ]]; then
  git clone "$LIBRECHAT_REPO" "$LIBRECHAT_DIR"
fi

cd "$LIBRECHAT_DIR"
git fetch --tags origin
git checkout "$LIBRECHAT_REF"
git pull --ff-only origin "$LIBRECHAT_REF" || true

if [[ ! -f .env ]]; then
  cp .env.example .env
fi

cp "$SCRIPT_DIR/librechat.yaml" "$LIBRECHAT_DIR/librechat.yaml"
cat > "$LIBRECHAT_DIR/docker-compose.override.yml" <<'EOF'
services:
  api:
    ports:
      - "127.0.0.1:3080:3080"
    extra_hosts:
      - "host.docker.internal:host-gateway"
    volumes:
      - type: bind
        source: ./librechat.yaml
        target: /app/librechat.yaml
EOF

if ! grep -q '^DOMAIN_CLIENT=' .env; then
  cat >> .env <<EOF

DOMAIN_CLIENT=https://${DOMAIN}
DOMAIN_SERVER=https://${DOMAIN}
TRUST_PROXY=1
EOF
fi

docker compose pull
docker compose up -d

install -d -m 0755 /etc/caddy/conf.d
sed "s/ai\\.ombhrum\\.com/${DOMAIN}/g" "$SCRIPT_DIR/Caddyfile" \
  > /etc/caddy/conf.d/ai.ombhrum.com.caddy

if ! grep -q 'import /etc/caddy/conf.d/\*.caddy' /etc/caddy/Caddyfile; then
  cp /etc/caddy/Caddyfile "/etc/caddy/Caddyfile.backup.$(date +%Y%m%d%H%M%S)"
  printf '\nimport /etc/caddy/conf.d/*.caddy\n' >> /etc/caddy/Caddyfile
fi

systemctl enable --now docker
systemctl enable --now caddy
caddy validate --config /etc/caddy/Caddyfile
systemctl reload caddy

echo "LibreChat domain deployment prepared for https://${DOMAIN}"
