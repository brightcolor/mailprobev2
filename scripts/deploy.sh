#!/usr/bin/env bash
# One-shot deploy: stop all running containers, start MailProbe via Docker Compose.
set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-/opt/mailprobe}"
HTTP_PORT="${HTTP_PORT:-8080}"
SMTP_PORT="${SMTP_PORT:-2525}"
MAILPROBE_IMAGE="${MAILPROBE_IMAGE:-ghcr.io/brightcolor/mailprobe:latest}"
REPO_URL="https://github.com/brightcolor/mailprobev2.git"

log() { printf '\033[1;34m[deploy]\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m[deploy] ERROR:\033[0m %s\n' "$*" >&2; exit 1; }

[[ "$(uname -s)" == "Linux" ]] || err "Linux only."
command -v docker >/dev/null 2>&1 || err "Docker not found. Install Docker first: curl -fsSL https://get.docker.com | sh"

# Stop all running containers
RUNNING=$(docker ps -q)
if [[ -n "$RUNNING" ]]; then
  log "Stopping $(docker ps -q | wc -l) running container(s)..."
  docker stop $RUNNING
  log "Containers stopped."
else
  log "No running containers found."
fi

# Clone or update repo
if [[ -d "$INSTALL_DIR/.git" ]]; then
  log "Updating repository in $INSTALL_DIR..."
  git -C "$INSTALL_DIR" pull --ff-only origin main
else
  log "Cloning repository to $INSTALL_DIR..."
  mkdir -p "$(dirname "$INSTALL_DIR")"
  git clone "$REPO_URL" "$INSTALL_DIR"
fi

# Write .env
cd "$INSTALL_DIR"
if [[ ! -f .env ]]; then
  cp .env.example .env
fi

set_env() {
  local k="$1" v="$2"
  if grep -qE "^${k}=" .env; then
    sed -i "s|^${k}=.*|${k}=${v}|" .env
  else
    echo "${k}=${v}" >> .env
  fi
}

IP=$(hostname -I 2>/dev/null | awk '{print $1}')
set_env HTTP_PORT     "$HTTP_PORT"
set_env SMTP_PORT     "$SMTP_PORT"
set_env MAILPROBE_IMAGE "$MAILPROBE_IMAGE"
set_env PUBLIC_BASE_URL "http://${IP}:${HTTP_PORT}"

# Start MailProbe
log "Pulling image and starting MailProbe..."
docker compose pull
docker compose up -d

cat <<EOF

  MailProbe läuft!

  Web:  http://${IP}:${HTTP_PORT}
  SMTP: ${IP}:${SMTP_PORT}

EOF
