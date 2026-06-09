#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

for env_file in .env .env.litellm .env.new-api; do
  if [[ -f "$env_file" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$env_file"
    set +a
  fi
done

base_url="${LITELLM_BASE_URL:-http://localhost:${LITELLM_PUBLIC_PORT:-4100}}"
key="${LITELLM_TEST_KEY:-${LITELLM_MASTER_KEY:-}}"
models_csv="${TEST_MODELS:-claude-sonnet-4-5,gemini-2.5-pro,deepseek-chat,qwen-plus,kimi-chat}"

if [[ -z "$key" ]]; then
  echo "请先设置 LITELLM_TEST_KEY，或在 .env.litellm 中配置 LITELLM_MASTER_KEY。" >&2
  exit 1
fi

IFS=',' read -r -a models <<< "$models_csv"

for model in "${models[@]}"; do
  model="$(echo "$model" | xargs)"
  [[ -z "$model" ]] && continue

  echo "==> 测试 ${model}"
  curl -sS "${base_url}/v1/messages" \
    -H "Authorization: Bearer ${key}" \
    -H "anthropic-version: 2023-06-01" \
    -H "content-type: application/json" \
    -d "{
      \"model\": \"${model}\",
      \"max_tokens\": 32,
      \"messages\": [{\"role\": \"user\", \"content\": \"只回复 OK\"}]
    }"
  echo
done
