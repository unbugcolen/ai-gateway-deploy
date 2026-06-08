# 团队 AI Gateway / 中转站部署包

目标：在一台固定 IP 服务器上部署团队统一 AI API 网关，集中管理 Claude Code、Codex/Cursor、服务端应用的模型入口、供应商 key、成员 token、预算、速率限制和使用记录。

本项目保留两个可落地方案：

- **LiteLLM Proxy**：团队工程治理推荐方案。
- **New API**：快速搭建中转站推荐方案。

## 推荐结论

如果是团队长期使用，首选 **LiteLLM Proxy**。

LiteLLM 更像工程团队的 LLM Gateway：virtual keys、团队/项目预算、fallback、路由、日志、Admin UI、OpenAI-compatible 与 Anthropic `/v1/messages` 都覆盖。Claude Code 官方 LLM gateway 文档也直接以 LiteLLM 作为示例方案之一。

如果诉求是“尽快有一个中文后台、渠道/用户/token/额度都能点点点配置”，选 **New API**。它更贴近国内常说的“中转站”，落地快，后台友好，但 AGPL 许可证和后续源码改造合规要提前确认。

## 方案总览

| 方案 | 定位 | 团队后台 | Claude Code | OpenAI-compatible | 多供应商 | 预算/限流 | 审计日志 | 一键部署 | 许可证/商业风险 | 推荐度 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| LiteLLM Proxy | 工程化 LLM Gateway | 中到强 | 强，支持 Anthropic 格式 | 强 | 很强 | 强 | 强 | 已提供 | 主体 MIT，注意企业版功能边界 | 首选 |
| New API | 产品化中转站后台 | 强 | 强，支持 Claude 原生格式 | 强 | 强 | 强 | 中到强 | 已提供 | AGPLv3，改造/对外服务需确认义务 | 次选 |
| Portkey | 商业级 AI Gateway | 强 | 中到强 | 强 | 很强 | 强 | 强 | 需另行评估 | 完整私有化更偏 enterprise/hybrid | 预算充足再看 |
| Helicone | 观测与分析层 | 中 | 中 | 强 | 中到强 | 中 | 强 | 需另行评估 | Apache 2.0，适合叠加观测 | 辅助方案 |
| One API | 老牌轻量中转 | 中 | 弱到中 | 强 | 中 | 中 | 中 | 可部署 | 维护活跃度与 Claude Code 适配弱于前两者 | 不优先 |
| Claude Code Router | 本机路由器 | 弱 | 强 | 弱 | 中 | 弱 | 弱 | npm 本机 | 不适合统一团队治理 | 不做团队主入口 |

## 关键维度对比

### Claude Code 适配

- **LiteLLM**：适合作为 Claude Code 的统一网关。Claude Code 要求网关至少支持 Anthropic Messages `/v1/messages` 和 `/v1/messages/count_tokens`，并转发 `anthropic-beta`、`anthropic-version` 等头。LiteLLM 覆盖这一类网关形态。
- **New API**：支持 Claude 原生 Messages API，Claude Code 可以配置 `ANTHROPIC_BASE_URL` 指向它。
- **Portkey/Helicone**：更偏通用 SDK/gateway/observability，Claude Code 要逐项验证 Anthropic 原生格式、模型发现、beta header 兼容。
- **Claude Code Router**：只适合个人本机把 Claude Code 路由到其他供应商，不适合作为团队固定 IP 中央网关。

### 团队治理

- **LiteLLM**：强在 virtual keys、团队/项目预算、默认预算上限、key 生成规则、fallback、日志和可编程配置。更适合平台化治理。
- **New API**：强在后台产品化，渠道、分组、用户、token、额度更容易由普通管理员维护。
- **Portkey**：功能完整，但完整团队控制台和私有化通常更偏商业方案。
- **Helicone**：更适合做调用观测、成本分析和日志，不建议单独承担团队 key 分发主入口。

### 运维复杂度

- **LiteLLM**：配置更工程化，需要维护 `config.yaml`、模型别名、provider key、预算策略。
- **New API**：后台点击配置更多，首轮落地更快。
- **Portkey**：如果只跑开源 gateway 很轻；如果要企业控制台、团队权限和私有化，需要商务/架构评估。

### 许可证

- **LiteLLM**：主体为 MIT，注意 enterprise 目录或商业功能边界。
- **New API**：AGPLv3；内部私有部署通常可行，但如果改源码并通过网络对外提供服务，需要团队确认 AGPL 义务或商业授权。
- **Helicone**：Apache 2.0，对企业内部二次开发更宽松。
- **Portkey**：开源 gateway 可用，但完整私有化能力按其商业方案评估。

## 目录结构

```text
ai-gateway-deploy/
├── README.md
├── litellm/
│   ├── docker-compose.yml
│   ├── .env.example
│   └── config.yaml
├── new-api/
│   ├── docker-compose.yml
│   └── .env.example
└── scripts/
    ├── deploy-litellm.sh
    └── deploy-new-api.sh
```

## 方案一：LiteLLM Proxy

适合：团队长期统一入口、项目预算、成员 token、fallback、可观测和工程化治理。

### 部署

```bash
cd /Users/colen/code/project/mindMatrix/ai-gateway-deploy
chmod +x scripts/deploy-litellm.sh
./scripts/deploy-litellm.sh --host 203.0.113.10 --user root
```

自定义端口：

```bash
./scripts/deploy-litellm.sh \
  --host 203.0.113.10 \
  --user root \
  --public-port 4000
```

脚本会在远端创建 `/opt/ai-gateway/litellm`，上传 `docker-compose.yml`、`.env.example`、`config.yaml`，自动生成 Postgres 密码、`LITELLM_MASTER_KEY`、`LITELLM_SALT_KEY`，然后执行 `docker compose pull && docker compose up -d`。

### 配置供应商 key

登录服务器：

```bash
ssh root@<固定IP>
cd /opt/ai-gateway/litellm
vim .env
```

填入需要的 key：

```text
ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-...
GEMINI_API_KEY=...
DEEPSEEK_API_KEY=...
```

重启：

```bash
docker compose up -d
```

### LiteLLM 管理台

```text
http://<固定IP>:4000/ui
```

使用远端 `.env` 里的 `LITELLM_MASTER_KEY` 登录或调用管理 API。建议为每个成员/项目创建独立 virtual key，并配置：

- `max_budget`
- `budget_duration`
- `rpm_limit`
- `tpm_limit`
- 可访问模型列表
- `tags`，用于成本归因

### Claude Code 使用

```bash
export ANTHROPIC_BASE_URL=http://<固定IP>:4000
export ANTHROPIC_AUTH_TOKEN=sk-成员或项目的-litellm-virtual-key
export CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1
```

如果把 Claude Code 请求转到非 Anthropic 原生供应商，遇到 beta/header 兼容错误时再加：

```bash
export CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS=1
```

### OpenAI-compatible 客户端使用

```bash
export OPENAI_BASE_URL=http://<固定IP>:4000/v1
export OPENAI_API_KEY=sk-成员或项目的-litellm-virtual-key
```

## 方案二：New API

适合：希望最快得到中文后台、渠道管理、用户/分组/token/额度管理的团队。

### 部署

```bash
cd /Users/colen/code/project/mindMatrix/ai-gateway-deploy
chmod +x scripts/deploy-new-api.sh
./scripts/deploy-new-api.sh --host 203.0.113.10 --user root
```

自定义端口：

```bash
./scripts/deploy-new-api.sh \
  --host 203.0.113.10 \
  --user root \
  --public-port 3000
```

如果后续绑定域名和 HTTPS：

```bash
./scripts/deploy-new-api.sh \
  --host api.example.com \
  --user root \
  --frontend-url https://api.example.com
```

脚本会在远端创建 `/opt/ai-gateway/new-api`，上传 `docker-compose.yml` 和 `.env.example`，自动生成 `.env` 里的数据库密码与 New API 加密密钥，然后执行 `docker compose pull && docker compose up -d`。

### 初始化后台

```text
http://<固定IP>:3000
```

首次打开会进入初始化页面，设置管理员账号和密码。

建议初始化后马上做这些事：

1. 新增供应商渠道：Anthropic Claude、OpenAI、Gemini、DeepSeek、OpenRouter 等。
2. 创建团队分组：如 `engineering`、`product`、`ops`。
3. 给每个成员或项目创建独立 token，不共用管理员 token。
4. 给 token 设置额度、可用模型、过期时间和速率限制。
5. 验证 Claude 原生接口：后台 token 应能访问 `/v1/messages`。

### Claude Code 使用

```bash
export ANTHROPIC_BASE_URL=http://<固定IP>:3000
export ANTHROPIC_AUTH_TOKEN=sk-你的-new-api-token
export CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1
```

### OpenAI-compatible 客户端使用

```bash
export OPENAI_BASE_URL=http://<固定IP>:3000/v1
export OPENAI_API_KEY=sk-你的-new-api-token
```

## 运维命令

LiteLLM：

```bash
ssh root@<固定IP>
cd /opt/ai-gateway/litellm
docker compose ps
docker compose logs -f litellm
docker compose pull
docker compose up -d
```

New API：

```bash
ssh root@<固定IP>
cd /opt/ai-gateway/new-api
docker compose ps
docker compose logs -f new-api
docker compose pull
docker compose up -d
```

备份 Postgres volume：

```bash
docker run --rm \
  -v "$(basename "$PWD")_postgres_data:/from:ro" \
  -v "$PWD/backup:/to" \
  alpine tar czf /to/postgres-data-$(date +%F).tgz -C /from .
```

## GitHub Actions 部署

本项目提供两个流水线：

- `Validate`：push/PR 到 `main` 时自动校验 shell 脚本语法和两个 Docker Compose 模板。
- `Deploy AI Gateway`：手动触发部署，支持选择 `litellm` 或 `new-api`。

### 运维需要配置的 GitHub Secrets / Variables

在 GitHub 仓库进入 `Settings -> Secrets and variables -> Actions`：

必填 Secret：

```text
AI_GATEWAY_SSH_PRIVATE_KEY
```

说明：目标服务器 SSH 私钥，要求能登录部署账号。推荐为该部署单独创建一把 key，不要复用个人日常 key。

可选 Repository Variable：

```text
AI_GATEWAY_HOST
```

说明：固定 IP 或域名。也可以每次运行流水线时在 `host` 输入框里填写。

### 手动部署步骤

1. 打开 GitHub 仓库的 `Actions`。
2. 选择 `Deploy AI Gateway`。
3. 点击 `Run workflow`。
4. 选择：
   - `gateway`: `litellm` 或 `new-api`
   - `host`: 固定 IP；为空时使用 `AI_GATEWAY_HOST`
   - `ssh_user`: 默认 `root`
   - `ssh_port`: 默认 `22`
   - `remote_path`: 为空时使用默认路径
   - `public_port`: 为空时使用默认端口
   - `frontend_url`: 仅 New API 需要，绑定域名/HTTPS 时填写

默认部署路径：

| 方案 | 默认远端路径 | 默认端口 |
| --- | --- | --- |
| LiteLLM | `/opt/ai-gateway/litellm` | `4000` |
| New API | `/opt/ai-gateway/new-api` | `3000` |

### 流水线部署后的人工配置

流水线只上传部署模板并启动容器，不会把供应商 API key 写进仓库。

LiteLLM：

```bash
ssh root@<固定IP>
cd /opt/ai-gateway/litellm
vim .env
docker compose up -d
```

New API：

```bash
ssh root@<固定IP>
cd /opt/ai-gateway/new-api
docker compose ps
```

New API 的供应商 key 建议在后台“渠道管理”里录入。

## 安全建议

- 不把任何上游供应商 key 写进 git。
- 不给成员发管理员 key；按人或项目发独立 token。
- 管理台不要裸露公网。固定 IP 直连时，至少用云安全组限制来源 IP；更推荐绑定域名、HTTPS、VPN 或 nginx basic auth。
- 网关会看到团队提示词和代码上下文，避免接入未知“低价中转站”作为上游。
- 生产环境优先用官方 Docker 镜像，关注安全公告并定期升级。
- LiteLLM 过去出现过 PyPI 供应链风险；服务器部署优先使用官方 Docker 镜像，不在服务器上随意 `pip install` 未确认版本。

## 资料来源

- LiteLLM: https://docs.litellm.ai/
- LiteLLM virtual keys: https://docs.litellm.com.cn/docs/proxy/virtual_keys
- Claude Code LLM Gateway: https://code.claude.com/docs/en/llm-gateway
- New API: https://github.com/QuantumNous/new-api
- New API Docker Compose: https://docs.newapi.pro/zh/docs/installation/deployment-methods/docker-compose-installation
- New API 环境变量: https://docs.newapi.pro/zh/docs/installation/config-maintenance/environment-variables
- New API Claude 原生格式: https://docs.newapi.pro/zh/docs/api/ai-model/chat/createmessage
- Portkey Gateway: https://github.com/Portkey-AI/gateway
- Helicone Open Source: https://docs.helicone.ai/references/open-source
