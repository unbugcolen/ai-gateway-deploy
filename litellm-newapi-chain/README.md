# LiteLLM 入口 + New API 渠道池

这个目录实现第三种组合方案：

```mermaid
flowchart LR
  A["员工 / Claude Code / Codex / Cursor"] --> B["LiteLLM 统一入口 :4000"]
  B --> C["New API 渠道池 :3000"]
  C --> D["xAI / Grok"]
  C --> E["OpenAI"]
  C --> F["Anthropic / Claude"]
  C --> G["其他供应商"]
```

## 能不能打通

能。关键点是把 **New API 当成 LiteLLM 的 OpenAI-compatible 下游**：

- Claude Code 调 LiteLLM 的 `ANTHROPIC_BASE_URL=http://<server>:4000`。
- LiteLLM 接收 `/v1/messages`，并把请求转换为 OpenAI chat/completions 格式。
- LiteLLM 使用 `NEW_API_SERVICE_TOKEN` 调 New API 的 `http://new-api:3000/v1`。
- New API 再按后台渠道池、模型名、分组和优先级转发到真实供应商。

员工只拿 LiteLLM virtual key。New API token 是 LiteLLM 内部服务 token，不发给员工。

## 适用场景

- 想用 LiteLLM 做团队统一入口、员工 key、预算、限流和 Claude Code 适配。
- 又想保留 New API 的中文后台、供应商渠道池、模型渠道测试和渠道优先级。
- 运维希望供应商 key 集中放在 New API 后台，LiteLLM 不直接保存供应商 key。

## 首次启动流程

### 1. 准备配置

```bash
cd /Users/colen/code/project/mindMatrix/ai-gateway-deploy/litellm-newapi-chain
cp .env.example .env
```

编辑 `.env`：

- `DATABASE_URL`：LiteLLM 使用的 PostgreSQL。
- `SQL_DSN`：New API 使用的 PostgreSQL。
- `REDIS_CONN_STRING`：New API 使用的 Redis。
- `LITELLM_MASTER_KEY`、`LITELLM_SALT_KEY`、`SESSION_SECRET`、`CRYPTO_SECRET`：生产环境必须改成随机强密钥。

本地 Docker Desktop 连接宿主机 PostgreSQL/Redis 时，可使用：

```env
DATABASE_URL=postgresql://litellm:password@host.docker.internal:5432/litellm
SQL_DSN=postgresql://newapi:password@host.docker.internal:5432/newapi
REDIS_CONN_STRING=redis://host.docker.internal:6379/0
```

### 2. 先启动 New API

```bash
docker compose up -d new-api
```

打开 New API 后台：

```text
http://localhost:3000
```

生产服务器默认只绑定 `127.0.0.1:3000`，远程访问建议走 SSH 隧道：

```bash
ssh -L 3000:127.0.0.1:3000 root@<server-ip>
```

### 3. 在 New API 配渠道池

在 New API 后台完成：

- 配置 xAI / Grok、OpenAI、Anthropic 等供应商渠道。
- 启用对应模型，例如 `grok-code-fast-1`。
- 本地自用或内部测试可开启“自用模式”；生产环境也可以给模型配置价格。
- 创建一个服务 token，专门给 LiteLLM 使用。

如果 Grok/xAI 作为 Claude Code 下游，建议在 New API 中配置为 OpenAI-compatible 渠道：

- 类型：OpenAI 兼容。
- Base URL：`https://api.x.ai`
- 模型：`grok-code-fast-1`

这样 LiteLLM 转换后的 OpenAI chat/completions 请求会更稳定。

### 4. 填 New API 服务 token

把 New API 后台创建的服务 token 写入 `.env`：

```env
NEW_API_SERVICE_TOKEN=sk-你的-new-api-服务-token
NEW_API_OPENAI_BASE_URL=http://new-api:3000/v1
```

### 5. 启动 LiteLLM

```bash
docker compose up -d litellm
```

LiteLLM UI/API：

```text
http://localhost:4000
```

使用 `.env` 里的 `LITELLM_MASTER_KEY` 登录管理 UI，并在 LiteLLM 里给员工创建 virtual key。

## Claude Code 员工配置

员工只配置 LiteLLM，不配置 New API：

```bash
export ANTHROPIC_BASE_URL="http://<server-ip>:4000"
export ANTHROPIC_AUTH_TOKEN="sk-员工的-litellm-virtual-key"
export ANTHROPIC_MODEL="grok-code-fast-1"
export ANTHROPIC_DEFAULT_SONNET_MODEL="grok-code-fast-1"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="grok-code-fast-1"
export ANTHROPIC_DEFAULT_OPUS_MODEL="grok-code-fast-1"
export CLAUDE_CODE_SUBAGENT_MODEL="grok-code-fast-1"
export CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1
export CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS=1
```

测试：

```bash
claude -p "只回复 OK" --model grok-code-fast-1
```

## OpenAI-compatible 客户端配置

Codex、Cursor、OpenAI SDK 或服务端应用使用 LiteLLM 的 OpenAI-compatible 入口：

```bash
export OPENAI_BASE_URL="http://<server-ip>:4000/v1"
export OPENAI_API_KEY="sk-员工的-litellm-virtual-key"
```

## 本地验证

使用 LiteLLM key 测 Anthropic Messages 入口：

```bash
curl -sS http://localhost:4000/v1/messages \
  -H "Authorization: Bearer $LITELLM_TEST_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{
    "model": "grok-code-fast-1",
    "max_tokens": 32,
    "messages": [{"role": "user", "content": "只回复 OK"}]
  }'
```

使用 LiteLLM key 测 OpenAI-compatible 入口：

```bash
curl -sS http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer $LITELLM_TEST_KEY" \
  -H "content-type: application/json" \
  -d '{
    "model": "grok-code-fast-1",
    "max_tokens": 32,
    "messages": [{"role": "user", "content": "只回复 OK"}]
  }'
```

## 排障

### LiteLLM 报 401

检查员工使用的是 LiteLLM virtual key，不是 New API token。员工不应该直接拿 New API 服务 token。

### LiteLLM 报 New API 401

检查 `.env` 中的 `NEW_API_SERVICE_TOKEN` 是否是 New API 后台生成的有效 token。

### New API 报模型价格未配置

在 New API 后台开启自用模式，或在“分组与模型定价设置”里给模型配置价格。

### Grok 在 chat/completions 能通，但 Claude Code 不通

这个组合方案下 Claude Code 先到 LiteLLM，LiteLLM 再用 OpenAI chat/completions 调 New API。优先确认 `NEW_API_OPENAI_BASE_URL=http://new-api:3000/v1`，并建议把 xAI 在 New API 中配置为 OpenAI-compatible 渠道，Base URL 使用 `https://api.x.ai`。

### 员工绕过 LiteLLM 直接打 New API

默认 Compose 已把 New API 绑定到 `127.0.0.1:3000`，生产环境还应通过防火墙或安全组限制 New API 端口，只开放 LiteLLM 入口。
