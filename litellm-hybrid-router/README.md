# LiteLLM 混合路由：官方直连 + New API 渠道池

这个目录实现你说的拓扑：

```mermaid
flowchart TD
  A["员工 / Claude Code / Codex / Cursor"] --> B["LiteLLM 统一入口"]
  B --> C["Claude 官方 API"]
  B --> D["Gemini 官方 API"]
  B --> E["OpenAI 官方 API"]
  B --> F["New API 渠道池"]
  F --> G["DeepSeek"]
  F --> H["Qwen"]
  F --> I["Kimi"]
```

## 为什么这个方式不错

这套方式比“所有模型都放进 New API”更均衡：

- Claude 官方 API 直连 LiteLLM：Claude Code 兼容性最好，减少 Anthropic Messages 转换链路。
- Gemini 官方 API 直连 LiteLLM：少一层转发，问题更容易定位。
- GPT 官方 API 直连 LiteLLM：避免 OpenAI key 和模型权限被 New API 二次路由影响，适合作为高阶备用和 Cursor BYOK 直连模型。
- DeepSeek / Qwen / Kimi 放 New API：利用 New API 的中文后台、渠道池、渠道测试、供应商 key 管理。
- 员工只接触 LiteLLM virtual key：预算、限流、离职回收都在 LiteLLM 做。
- New API 不直接暴露给员工：它只是下游渠道池和管理后台。

## 端口

为了避免和现有本地服务冲突，默认端口是：

- LiteLLM：`http://localhost:4100`
- New API 后台：`http://localhost:3100`

生产环境可以在 `.env` 里改回：

```env
LITELLM_PUBLIC_PORT=4000
NEW_API_ADMIN_PORT=3000
```

## 启动步骤

### 1. 准备配置文件

```bash
cd /Users/colen/code/project/mindMatrix/ai-gateway-deploy/litellm-hybrid-router
cp .env.example .env
cp .env.litellm.example .env.litellm
cp .env.new-api.example .env.new-api
```

三份文件分工：

- `.env`：Compose 项目名、镜像、端口、时区、可选代理。
- `.env.litellm`：LiteLLM 数据库、Claude/Gemini/GPT 官方 key、New API 服务 token。
- `.env.new-api`：New API 数据库、Redis、后台密钥、运行策略。

编辑 `.env.litellm`：

- `DATABASE_URL`：LiteLLM 使用的 PostgreSQL。
- `ANTHROPIC_API_KEY`：Claude 官方 API key。
- `GEMINI_API_KEY`：Gemini 官方 API key。
- `OPENAI_API_KEY`：OpenAI 官方 API key。
- `LITELLM_MASTER_KEY`、`LITELLM_SALT_KEY`：生产环境必须换成随机强密钥。
- `NEW_API_SERVICE_TOKEN`：第 3 步在 New API 后台创建后再填写。

编辑 `.env.new-api`：

- `SQL_DSN`：New API 使用的 PostgreSQL。
- `REDIS_CONN_STRING`：New API 使用的 Redis。
- `SESSION_SECRET`、`CRYPTO_SECRET`：生产环境必须换成随机强密钥。

本地 Docker Desktop 连接宿主机 PostgreSQL/Redis 示例：

`.env.litellm`：

```env
DATABASE_URL=postgresql://litellm:password@host.docker.internal:5432/litellm_hybrid
```

`.env.new-api`：

```env
SQL_DSN=postgresql://newapi:password@host.docker.internal:5432/newapi_hybrid
REDIS_CONN_STRING=redis://host.docker.internal:6379/1
```

### 2. 启动 New API

```bash
docker compose -f docker-compose.new-api.yml up -d
```

打开后台：

```text
http://localhost:3100
```

生产服务器默认建议只绑定 `127.0.0.1`，远程运维通过 SSH 隧道访问：

```bash
ssh -L 3100:127.0.0.1:3100 root@<server-ip>
```

### 3. 在 New API 配 DeepSeek / Qwen / Kimi

在 New API 后台配置渠道：

- DeepSeek：模型建议 `deepseek-chat`、`deepseek-reasoner`。
- Qwen：模型建议 `qwen-plus`、`qwen-coder-plus`。
- Kimi：模型建议 `moonshot-v1-8k`、`moonshot-v1-128k`。

然后创建一个“服务 token”，专门给 LiteLLM 使用：

- 分组：建议单独建 `litellm-upstream`，也可以先用 `default`。
- 模型权限：只开放 DeepSeek / Qwen / Kimi。
- 额度：按团队总预算设置。

把这个 token 写入 `.env.litellm`：

```env
NEW_API_SERVICE_TOKEN=sk-你的-new-api-服务-token
```

### 4. 启动 LiteLLM

```bash
docker compose -f docker-compose.litellm.yml up -d
```

LiteLLM UI/API：

```text
http://localhost:4100
```

用 `.env.litellm` 里的 `LITELLM_MASTER_KEY` 登录 LiteLLM UI，并给员工创建 virtual key。

### 一键启动方式

如果确认 `.env.litellm` 里已经有有效的 `NEW_API_SERVICE_TOKEN`，也可以使用原始的一体化 Compose 文件：

```bash
docker compose up -d
```

运维上更推荐分离启动：

- 单独升级 New API：`docker compose -f docker-compose.new-api.yml up -d`
- 单独升级 LiteLLM：`docker compose -f docker-compose.litellm.yml up -d`
- 查看 New API 日志：`docker compose -f docker-compose.new-api.yml logs -f new-api`
- 查看 LiteLLM 日志：`docker compose -f docker-compose.litellm.yml logs -f litellm`

## 员工 Claude Code 配置

推荐默认使用 Claude 官方模型：

```bash
export ANTHROPIC_BASE_URL="http://<server-ip>:4100"
export ANTHROPIC_AUTH_TOKEN="sk-员工的-litellm-virtual-key"
export ANTHROPIC_MODEL="claude-sonnet-4-5"
export ANTHROPIC_DEFAULT_SONNET_MODEL="claude-sonnet-4-5"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="claude-haiku-4-5"
export ANTHROPIC_DEFAULT_OPUS_MODEL="claude-sonnet-4-5"
export CLAUDE_CODE_SUBAGENT_MODEL="claude-sonnet-4-5"
export CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1
```

临时切到 New API 下游模型：

```bash
claude -p "只回复 OK" --model deepseek-chat
claude -p "只回复 OK" --model qwen-plus
claude -p "只回复 OK" --model kimi-chat
```

## OpenAI-compatible 客户端配置

Codex、Cursor、OpenAI SDK 或服务端应用统一接 LiteLLM：

```bash
export OPENAI_BASE_URL="http://<server-ip>:4100/v1"
export OPENAI_API_KEY="sk-员工的-litellm-virtual-key"
```

## 模型路由表

| 员工使用的模型名 | LiteLLM 去向 | 实际上游 |
| --- | --- | --- |
| `claude-sonnet-4-5` | LiteLLM 直连 | Claude 官方 API |
| `claude-haiku-4-5` | LiteLLM 直连 | Claude 官方 API |
| `gemini-2.5-pro` | LiteLLM 直连 | Gemini 官方 API |
| `gemini-2.5-flash` | LiteLLM 直连 | Gemini 官方 API |
| `gpt-5.5` | LiteLLM 直连 | OpenAI 官方 API |
| `gpt-4.1` | LiteLLM 直连 | OpenAI 官方 API |
| `gpt-4o` | LiteLLM 直连 | OpenAI 官方 API |
| `deepseek-chat` | LiteLLM -> New API | New API DeepSeek 渠道 |
| `deepseek-reasoner` | LiteLLM -> New API | New API DeepSeek 渠道 |
| `qwen-plus` | LiteLLM -> New API | New API Qwen 渠道 |
| `qwen-coder-plus` | LiteLLM -> New API | New API Qwen 渠道 |
| `kimi-chat` | LiteLLM -> New API | New API Kimi `moonshot-v1-8k` |
| `kimi-long-context` | LiteLLM -> New API | New API Kimi `moonshot-v1-128k` |

## 本地验证

创建员工 LiteLLM key 后：

```bash
export LITELLM_TEST_KEY="sk-员工的-litellm-virtual-key"
./smoke-test.sh
```

只测某几个模型：

```bash
TEST_MODELS="claude-sonnet-4-5,gpt-4.1,deepseek-chat,qwen-plus,kimi-chat" ./smoke-test.sh
```

## 使用记录与 Langfuse

推荐把 LiteLLM 作为成本和预算的主数据源，把 Langfuse 作为 LLM trace、慢请求、错误请求和质量分析系统。

生产默认建议：

- 开启 Langfuse metadata trace。
- 不记录 prompt/response 正文。
- 不把员工原始 token 写入观测系统。

配置参考：

- [使用记录与 Langfuse 接入方案](../docs/observability-langfuse-plan.md)
- [LiteLLM Langfuse 配置片段](./litellm-observability.langfuse.snippet.yaml)

## 排障

### Claude/Gemini 报 401

检查 `.env.litellm` 中的 `ANTHROPIC_API_KEY` 或 `GEMINI_API_KEY` 是否有效。这里不经过 New API。

### GPT 报 401 或组织无权限

检查 `.env.litellm` 中的 `OPENAI_API_KEY` 是否有效，以及 OpenAI 项目/组织是否开通对应模型权限。这里不经过 New API。

### DeepSeek/Qwen/Kimi 报 401

检查 `.env.litellm` 中的 `NEW_API_SERVICE_TOKEN` 是否是 New API 后台生成的有效 token。

### DeepSeek/Qwen/Kimi 报 model not found

检查 New API 后台是否存在对应模型，并且服务 token 所属分组有权限使用该模型。

### New API 报模型价格未配置

在 New API 后台开启自用模式，或在“分组与模型定价设置”里给模型配置价格。

### 员工绕过 LiteLLM 直接打 New API

默认 Compose 已把 New API 绑定到 `127.0.0.1:3100`。生产环境还应通过防火墙或安全组限制 New API 端口，只开放 LiteLLM 入口。
