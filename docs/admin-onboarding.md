# 管理员 AI Gateway 对接与发放说明

本文面向负责部署、配置、发放员工 token 和处理故障的管理员或运维。

## 管理员职责

- 部署并维护 LiteLLM 或 New API 网关。
- 配置上游供应商 key，例如 DeepSeek、Anthropic、OpenAI、Gemini。
- 为员工或项目发放独立 token。
- 限制 token 的模型、额度、过期时间和速率。
- 控制访问来源，例如公司出口 IP、VPN、Tailscale 或云安全组白名单。
- 处理员工接入问题和 token 回收。

不要把上游供应商 key 直接发给员工。员工只应该拿到网关发放的个人 token。

## 推荐上线前检查

上线前至少确认：

- 网关服务已通过 HTTPS 或公司内网/VPN 暴露。
- 服务器安全组只放行必要来源 IP。
- PostgreSQL 和 Redis 不对公网开放。
- `.env` 中的密钥不是占位符。
- `SESSION_SECRET`、`CRYPTO_SECRET`、`LITELLM_MASTER_KEY`、`LITELLM_SALT_KEY` 已妥善备份。
- 每个员工或项目使用独立 token。
- 默认 token 自动生成已关闭。
- 已准备员工接入文档：[employee-onboarding.md](employee-onboarding.md)。

## LiteLLM 管理员流程

### 1. 配置外部数据库

在服务器上编辑：

```bash
cd /opt/ai-gateway/litellm
vim .env
```

确认数据库连接串已改成生产环境地址：

```env
DATABASE_URL=postgresql://litellm:password@postgres.internal.company:5432/litellm
```

### 2. 配置上游供应商 key

只填写公司已经采购或允许使用的供应商：

```env
ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-...
GEMINI_API_KEY=...
DEEPSEEK_API_KEY=...
```

修改后重启：

```bash
docker compose up -d
```

### 3. 登录管理台

访问：

```text
https://ai-gateway.example.com/ui
```

使用 `.env` 中的 `LITELLM_MASTER_KEY` 登录。该 key 是管理员/root 权限，不要发给员工。

### 4. 创建员工 virtual key

建议按“员工”或“项目”创建独立 key。创建时至少配置：

- Key Alias：例如 `alice-claude-code` 或 `project-payment-bot`
- Models：只勾选允许使用的模型
- Max Budget：预算上限
- Budget Duration：预算周期，例如 `30d`
- Duration：key 有效期，例如 `90d`
- RPM Limit：每分钟请求数
- TPM Limit：每分钟 token 数

DeepSeek-only 场景下，只给员工开放：

```text
deepseek-chat
```

不要开放尚未配置上游 key 的模型别名。

### 5. 验证模型列表

管理员可在服务器上验证：

```bash
cd /opt/ai-gateway/litellm
export LITELLM_MASTER_KEY="$(awk -F= '$1 == "LITELLM_MASTER_KEY" { sub(/^[^=]*=/, ""); print; exit }' .env)"

curl -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  https://ai-gateway.example.com/v1/models
```

应该能看到当前开放的模型别名，例如：

```text
deepseek-chat
claude-sonnet-4-5
gpt-5-mini
gemini-2.5-pro
```

如果只配置了 DeepSeek key，员工实际可用的模型应只发 `deepseek-chat`。

## New API 管理员流程

### 1. 配置外部数据库和 Redis

在服务器上编辑：

```bash
cd /opt/ai-gateway/new-api
vim .env
```

确认连接串已改成生产环境地址：

```env
SQL_DSN=postgresql://newapi:password@postgres.internal.company:5432/newapi
REDIS_CONN_STRING=redis://:password@redis.internal.company:6379/0
```

修改后重启：

```bash
docker compose up -d
```

### 2. 初始化管理员账号

访问：

```text
https://ai-gateway.example.com
```

首次打开时创建管理员账号。管理员账号不要和员工共用。

### 3. 关闭开放注册

进入系统设置，建议：

- 关闭开放注册。
- 如必须开放注册，限制邮箱域名白名单。
- 开启验证码或 Turnstile。
- 管理后台只允许公司 IP、VPN 或运维网络访问。

### 4. 配置渠道

在“渠道管理”中添加已采购的供应商渠道，例如：

- DeepSeek
- Anthropic Claude
- OpenAI
- Gemini
- OpenRouter

每个渠道保存后先做模型测试。测试失败的渠道不要开放给员工。

### 5. 创建员工 token

建议按员工或项目创建 token，并配置：

- 可用分组
- 可用模型
- 额度
- 过期时间
- 速率限制
- IP 白名单

DeepSeek-only 场景下，只给员工开放 DeepSeek 对应模型。

## CC Switch 策略

CC Switch 不是必须组件。管理员可以按团队情况选择：

- 普通员工：优先发环境变量配置，减少工具依赖。
- 频繁切换多个 provider 的员工：允许使用 CC Switch。
- 需要统一管理 Claude Code、Codex、Gemini CLI 配置的团队：可以把 CC Switch 作为推荐工具。

给员工 CC Switch 配置时，不要给管理员 key，只给个人 token。

Claude Code provider 信息：

```text
名称：Company AI Gateway
类型：Custom / Anthropic-compatible / LLM Gateway
Base URL：https://ai-gateway.example.com
API Key / Auth Token：员工个人 token
默认模型：deepseek-chat
```

OpenAI-compatible provider 信息：

```text
名称：Company AI Gateway OpenAI
Base URL：https://ai-gateway.example.com/v1
API Key：员工个人 token
默认模型：deepseek-chat
```

## DeepSeek-only 场景说明

如果当前只配置了 DeepSeek 上游 key：

- 员工只能稳定使用 DeepSeek 模型。
- Claude、OpenAI、Gemini 的模型别名即使出现在配置文件中，也会因为缺少上游 key 而失败。
- 员工文档和发放信息中只写 `deepseek-chat`，避免误选。
- Claude Code 可以通过 LiteLLM 或 New API 做 Anthropic-compatible 格式转换，但非 Claude 原生模型可能存在部分高级能力差异。

如后续采购 Anthropic、OpenAI、Gemini，只需要：

1. 在 `.env` 或后台渠道中补对应上游 key。
2. 验证模型调用。
3. 在员工 token 中开放对应模型。
4. 通知员工新增可用模型。

## 安全策略

### 网络层

- 云安全组只允许公司出口 IP、VPN 出口 IP 或运维固定 IP 访问网关。
- SSH 只允许运维 IP。
- PostgreSQL 和 Redis 只允许网关服务器访问。
- 远程员工较多时，优先使用 VPN、Tailscale、ZeroTier 或 Cloudflare Access。

### 账号和 token

- 管理员 key 不发给员工。
- 员工离职、转岗、项目结束后立即吊销 token。
- 发现泄露后立即禁用 token，并重新发放。
- 不要多个员工共用同一个 token。
- 生产 token 建议设置过期时间。

### 网关暴露

- 生产环境建议使用 HTTPS。
- 管理后台可以比 API 更严格，只允许运维网络访问。
- 如直接用固定 IP 暴露端口，必须配安全组白名单。
- 不建议公网裸露 `3000` 或 `4000`。

## 发给员工的信息模板

复制下面模板，替换后发给员工：

```text
网关类型：LiteLLM
网关地址：https://ai-gateway.example.com
个人 token：sk-xxxx
可用模型：deepseek-chat
访问要求：需要连接公司 VPN
员工文档：docs/employee-onboarding.md

Claude Code 配置：
export ANTHROPIC_BASE_URL="https://ai-gateway.example.com"
export ANTHROPIC_AUTH_TOKEN="sk-xxxx"
export CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1

启动：
claude --model deepseek-chat

OpenAI-compatible 配置：
export OPENAI_BASE_URL="https://ai-gateway.example.com/v1"
export OPENAI_API_KEY="sk-xxxx"
```

New API 模板：

```text
网关类型：New API
网关地址：https://ai-gateway.example.com
个人 token：sk-xxxx
可用模型：deepseek-chat
访问要求：需要连接公司 VPN
员工文档：docs/employee-onboarding.md

Claude Code 配置：
export ANTHROPIC_BASE_URL="https://ai-gateway.example.com"
export ANTHROPIC_AUTH_TOKEN="sk-xxxx"
export CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1

启动：
claude --model deepseek-chat

OpenAI-compatible 配置：
export OPENAI_BASE_URL="https://ai-gateway.example.com/v1"
export OPENAI_API_KEY="sk-xxxx"
```

## 常见故障定位

### 员工报 401

检查 token 是否复制错误、过期、被禁用，或员工混用了 New API 和 LiteLLM 的 token。

### 员工报 403

检查预算、RPM、TPM、模型权限和 IP 白名单。

### 员工报 model not found

检查员工使用的模型名是否在网关中存在，并且该员工 token 是否允许访问该模型。

### 员工报 provider authentication failed

通常是上游供应商 key 未配置、失效或余额不足。管理员应先用管理 key 或后台测试渠道。

### Claude Code 使用 DeepSeek 不稳定

先让员工增加：

```bash
export CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS=1
```

如果仍不稳定，优先切换到 Claude 原生模型，或收集报错、模型名、时间点、员工 token alias 后排查网关日志。

### 连接超时

检查员工是否在公司 VPN 或 IP 白名单内，安全组是否放行，Nginx/Caddy 反代是否正常。

## 下线和轮换

定期执行：

- 清理长期未使用 token。
- 轮换离职员工 token。
- 检查上游 key 是否仍有效。
- 检查网关容器镜像版本和安全公告。
- 备份 PostgreSQL。
- 检查访问日志中是否有异常来源 IP。
