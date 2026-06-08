#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  deploy-new-api.sh --host <server-ip-or-domain> [options]

Options:
  --host <value>          Required. Server IP or DNS name used for SSH and URL.
  --user <value>          SSH user. Default: root
  --ssh-port <value>      SSH port. Default: 22
  --path <value>          Remote install path. Default: /opt/ai-gateway/new-api
  --public-port <value>   Host port exposed by New API. Default: 3000
  --frontend-url <value>  Public URL shown to New API. Default: http://<host>:<public-port>
  -h, --help              Show help.

Example:
  ./scripts/deploy-new-api.sh --host 203.0.113.10 --user root
USAGE
}

host=""
ssh_user="root"
ssh_port="22"
remote_path="/opt/ai-gateway/new-api"
public_port="3000"
frontend_url=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)
      host="${2:-}"
      shift 2
      ;;
    --user)
      ssh_user="${2:-}"
      shift 2
      ;;
    --ssh-port)
      ssh_port="${2:-}"
      shift 2
      ;;
    --path)
      remote_path="${2:-}"
      shift 2
      ;;
    --public-port)
      public_port="${2:-}"
      shift 2
      ;;
    --frontend-url)
      frontend_url="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$host" ]]; then
  echo "Missing required --host" >&2
  usage
  exit 1
fi

if [[ -z "$frontend_url" ]]; then
  frontend_url="http://${host}:${public_port}"
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
gateway_dir="$(cd "${script_dir}/.." && pwd)"
bundle_dir="${gateway_dir}/new-api"

if [[ ! -f "${bundle_dir}/docker-compose.yml" || ! -f "${bundle_dir}/.env.example" ]]; then
  echo "Deployment bundle is incomplete: ${bundle_dir}" >&2
  exit 1
fi

for cmd in ssh rsync; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required local command: $cmd" >&2
    exit 1
  fi
done

ssh_target="${ssh_user}@${host}"
ssh_opts=(-p "$ssh_port" -o StrictHostKeyChecking=accept-new)

echo "==> Preparing remote directory: ${ssh_target}:${remote_path}"
ssh "${ssh_opts[@]}" "$ssh_target" "mkdir -p '$remote_path'"

echo "==> Uploading New API deployment bundle"
rsync -az \
  -e "ssh -p ${ssh_port} -o StrictHostKeyChecking=accept-new" \
  "${bundle_dir}/docker-compose.yml" \
  "${bundle_dir}/.env.example" \
  "${ssh_target}:${remote_path}/"

echo "==> Installing Docker if needed and starting services"
ssh "${ssh_opts[@]}" "$ssh_target" \
  "REMOTE_PATH='$remote_path' PUBLIC_PORT='$public_port' FRONTEND_URL='$frontend_url' bash -s" <<'REMOTE'
set -euo pipefail

cd "$REMOTE_PATH"

random_hex() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 32
  else
    tr -dc 'a-f0-9' </dev/urandom | head -c 64
  fi
}

install_docker() {
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    return
  fi

  if command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y ca-certificates curl gnupg docker.io docker-compose-plugin
    systemctl enable --now docker || true
    return
  fi

  if command -v yum >/dev/null 2>&1; then
    yum install -y docker docker-compose-plugin
    systemctl enable --now docker || true
    return
  fi

  echo "Docker is not installed and this script only auto-installs on apt/yum systems." >&2
  exit 1
}

install_docker

if [[ ! -f .env ]]; then
  cp .env.example .env
  postgres_password="$(random_hex)"
  session_secret="$(random_hex)"
  crypto_secret="$(random_hex)"

  sed -i "s|^PUBLIC_PORT=.*|PUBLIC_PORT=${PUBLIC_PORT}|" .env
  sed -i "s|^FRONTEND_BASE_URL=.*|FRONTEND_BASE_URL=${FRONTEND_URL}|" .env
  sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=${postgres_password}|" .env
  sed -i "s|^SESSION_SECRET=.*|SESSION_SECRET=${session_secret}|" .env
  sed -i "s|^CRYPTO_SECRET=.*|CRYPTO_SECRET=${crypto_secret}|" .env
  chmod 600 .env
else
  echo "Existing .env found; keeping current secrets and settings."
fi

docker compose pull
docker compose up -d

echo "==> Waiting for New API health check"
for _ in $(seq 1 40); do
  if docker compose ps new-api | grep -q "healthy"; then
    break
  fi
  sleep 3
done

docker compose ps
REMOTE

echo
echo "Deployed New API gateway."
echo "URL: ${frontend_url}"
echo "Remote path: ${ssh_target}:${remote_path}"
echo
echo "First visit the URL to initialize the admin account, then add provider channels and create team tokens."
