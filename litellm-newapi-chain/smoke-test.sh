#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

base_url="${LITELLM_BASE_URL:-http://localhost:${LITELLM_PUBLIC_PORT:-4000}}"
model="${TEST_MODEL:-grok-code-fast-1}"
key="${LITELLM_TEST_KEY:-${LITELLM_MASTER_KEY:-}}"

if [[ -z "$key" ]]; then
  echo "请先设置 LITELLM_TEST_KEY，或在 .env 中配置 LITELLM_MASTER_KEY。" >&2
  exit 1
fi

echo "测试 LiteLLM Anthropic Messages 入口：${base_url}/v1/messages"
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
echo "测试 LiteLLM OpenAI-compatible 入口：${base_url}/v1/chat/completions"
curl -sS "${base_url}/v1/chat/completions" \
  -H "Authorization: Bearer ${key}" \
  -H "content-type: application/json" \
  -d "{
    \"model\": \"${model}\",
    \"max_tokens\": 32,
    \"messages\": [{\"role\": \"user\", \"content\": \"只回复 OK\"}]
  }"

echo
