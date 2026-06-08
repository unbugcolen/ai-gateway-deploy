#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  deploy-litellm.sh --host <server-ip-or-domain> [options]

Options:
  --host <value>          Required. Server IP or DNS name used for SSH and URL.
  --user <value>          SSH user. Default: root
  --ssh-port <value>      SSH port. Default: 22
  --path <value>          Remote install path. Default: /opt/ai-gateway/litellm
  --public-port <value>   Host port exposed by LiteLLM. Default: 4000
  --with-bundled-deps     Also deploy bundled PostgreSQL. Use only for local/test.
  -h, --help              Show help.

Example:
  ./scripts/deploy-litellm.sh --host 203.0.113.10 --user root
USAGE
}

host=""
ssh_user="root"
ssh_port="22"
remote_path="/opt/ai-gateway/litellm"
public_port="4000"
with_bundled_deps="false"

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
    --with-bundled-deps)
      with_bundled_deps="true"
      shift
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

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
gateway_dir="$(cd "${script_dir}/.." && pwd)"
bundle_dir="${gateway_dir}/litellm"

if [[ ! -f "${bundle_dir}/docker-compose.yml" || ! -f "${bundle_dir}/docker-compose.bundled.yml" || ! -f "${bundle_dir}/.env.example" || ! -f "${bundle_dir}/config.yaml" ]]; then
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

echo "==> Uploading LiteLLM deployment bundle"
rsync -az \
  -e "ssh -p ${ssh_port} -o StrictHostKeyChecking=accept-new" \
  "${bundle_dir}/docker-compose.yml" \
  "${bundle_dir}/docker-compose.bundled.yml" \
  "${bundle_dir}/.env.example" \
  "${bundle_dir}/config.yaml" \
  "${ssh_target}:${remote_path}/"

echo "==> Installing Docker if needed and starting services"
ssh "${ssh_opts[@]}" "$ssh_target" \
  "REMOTE_PATH='$remote_path' PUBLIC_PORT='$public_port' WITH_BUNDLED_DEPS='$with_bundled_deps' bash -s" <<'REMOTE'
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
    yum install -y docker docker-compose-plugin curl
    systemctl enable --now docker || true
    return
  fi

  echo "Docker is not installed and this script only auto-installs on apt/yum systems." >&2
  exit 1
}

install_docker

get_env_value() {
  local key="$1"
  awk -F= -v key="$key" '$1 == key { sub(/^[^=]*=/, ""); print; exit }' .env 2>/dev/null || true
}

is_placeholder_value() {
  local value="$1"
  [[ -z "$value" || "$value" == *"CHANGE_ME"* || "$value" == *"example.internal"* ]]
}

if [[ ! -f .env ]]; then
  cp .env.example .env
  postgres_password="$(random_hex)"
  master_key="sk-$(random_hex)"
  salt_key="sk-$(random_hex)"

  sed -i "s|^PUBLIC_PORT=.*|PUBLIC_PORT=${PUBLIC_PORT}|" .env
  sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=${postgres_password}|" .env
  sed -i "s|^LITELLM_MASTER_KEY=.*|LITELLM_MASTER_KEY=${master_key}|" .env
  sed -i "s|^LITELLM_SALT_KEY=.*|LITELLM_SALT_KEY=${salt_key}|" .env
  chmod 600 .env
else
  echo "Existing .env found; keeping current secrets and provider keys."
fi

compose_files=(-f docker-compose.yml)
if [[ "$WITH_BUNDLED_DEPS" == "true" ]]; then
  compose_files+=(-f docker-compose.bundled.yml)
else
  database_url="$(get_env_value DATABASE_URL)"
  if is_placeholder_value "$database_url"; then
    echo "External dependency mode requires a real DATABASE_URL in ${REMOTE_PATH}/.env." >&2
    echo "Edit the remote .env with an ops-managed PostgreSQL endpoint, then rerun this deploy script." >&2
    echo "For local/test only, rerun with --with-bundled-deps to start bundled PostgreSQL." >&2
    exit 1
  fi
fi

docker compose "${compose_files[@]}" pull
docker compose "${compose_files[@]}" up -d

echo "==> Waiting for LiteLLM endpoint"
for _ in $(seq 1 40); do
  if curl -fsS "http://127.0.0.1:${PUBLIC_PORT}/health/readiness" >/dev/null 2>&1; then
    break
  fi
  sleep 3
done

docker compose "${compose_files[@]}" ps
REMOTE

echo
echo "Deployed LiteLLM gateway."
echo "API URL: http://${host}:${public_port}"
echo "UI URL:  http://${host}:${public_port}/ui"
echo "Remote path: ${ssh_target}:${remote_path}"
echo "Bundled dependencies: ${with_bundled_deps}"
echo
echo "Edit remote .env with provider keys, then run: cd ${remote_path} && docker compose up -d"
