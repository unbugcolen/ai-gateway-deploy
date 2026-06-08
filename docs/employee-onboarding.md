# 员工接入 AI Gateway 使用说明

本文面向需要使用 Claude Code、Codex、Cursor 或 OpenAI-compatible SDK 的员工。

本文只包含员工本地接入步骤。后台配置、token 发放、模型开放和安全策略由管理员处理。

## 向管理员领取的信息

接入前，请先向管理员确认：

- 网关类型：`LiteLLM` 或 `New API`
- 网关地址：例如 `https://ai-gateway.example.com`
- 个人 token：例如 `sk-...`
- 可用模型：例如 `deepseek-chat`、`claude-sonnet-4-5`、`gpt-5.5`
- 是否必须通过公司 VPN 或固定办公网络访问

不要索要或保存上游供应商 key。员工只使用网关发放的个人 token。

## 是否必须安装 CC Switch

不必须。

Claude Code 直接设置环境变量就可以接入公司网关。CC Switch 只是一个本地配置管理工具，适合这些场景：

- 经常在公司网关、个人账号、测试网关之间切换
- 不想手动编辑 shell 环境变量
- 同时管理 Claude Code、Codex、Gemini CLI 等多个工具
- 希望通过桌面 UI 维护 provider、MCP、Skills、Prompt 配置

团队推荐优先使用“直接环境变量”方式。员工需要频繁切换时，再使用 CC Switch。

## Claude Code 接入 LiteLLM

LiteLLM 走 Anthropic-compatible 网关入口时，地址不要加 `/v1`。

```bash
export ANTHROPIC_BASE_URL="https://ai-gateway.example.com"
export ANTHROPIC_AUTH_TOKEN="sk-你的个人-litellm-token"
export CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1
```

启动 Claude Code：

```bash
claude
```

指定模型启动：

```bash
claude --model deepseek-chat
```

如果管理员配置的是真实 Claude 模型，也可以使用：

```bash
claude --model claude-sonnet-4-5
```

如果管理员开放了 OpenAI GPT 模型，也可以使用：

```bash
claude --model gpt-5.5
```

如果使用 DeepSeek、Gemini 等非 Anthropic 原生模型时遇到 beta/header 兼容问题，再增加：

```bash
export CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS=1
```

## Claude Code 接入 New API

New API 也使用 Anthropic-compatible 入口时，地址不要加 `/v1`。

```bash
export ANTHROPIC_BASE_URL="https://ai-gateway.example.com"
export ANTHROPIC_AUTH_TOKEN="sk-你的个人-new-api-token"
export CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1
```

启动：

```bash
claude
```

指定模型：

```bash
claude --model deepseek-chat
```

## OpenAI-compatible 客户端接入

Codex、Cursor、OpenAI SDK、LangChain 等 OpenAI-compatible 客户端通常使用 `/v1` 地址。

LiteLLM 示例：

```bash
export OPENAI_BASE_URL="https://ai-gateway.example.com/v1"
export OPENAI_API_KEY="sk-你的个人-litellm-token"
```

New API 示例：

```bash
export OPENAI_BASE_URL="https://ai-gateway.example.com/v1"
export OPENAI_API_KEY="sk-你的个人-new-api-token"
```

调用时模型名使用管理员告知的别名，例如：

```text
deepseek-chat
gpt-5.5
gemini-2.5-pro
```

## 使用 CC Switch 接入

如果团队要求或个人需要使用 CC Switch，可以按下面方式添加自定义 provider。

### Claude Code provider

在 CC Switch 中添加自定义 Claude Code provider：

```text
名称：Company AI Gateway
类型：Custom / Anthropic-compatible / LLM Gateway
Base URL：https://ai-gateway.example.com
API Key / Auth Token：sk-你的个人-token
默认模型：deepseek-chat
```

保存后切换到该 provider，再启动 Claude Code：

```bash
claude
```

如果 CC Switch 当前版本没有默认模型字段，可以在启动时显式指定：

```bash
claude --model deepseek-chat
```

### Codex 或 OpenAI-compatible provider

在 CC Switch 中添加 OpenAI-compatible provider：

```text
名称：Company AI Gateway OpenAI
Base URL：https://ai-gateway.example.com/v1
API Key：sk-你的个人-token
默认模型：deepseek-chat
```

保存后切换到该 provider，再打开 Codex、Cursor 或对应 CLI。

## 如果当前只配置了 DeepSeek key

只配置 DeepSeek 上游 key 时，员工只能稳定使用 DeepSeek 对应的模型别名，例如：

```text
deepseek-chat
```

其他模型别名即使在配置文件里存在，也需要管理员在网关上配置对应供应商 key 后才能使用。例如：

- `claude-sonnet-4-5` 需要 Anthropic key
- `gpt-5.5` 需要 OpenAI key
- `gemini-2.5-pro` 需要 Gemini key

管理员发 token 时，建议只给员工开放已经配置成功的模型，避免员工选到不可用模型。

## 常见问题

### 401 或 Unauthorized

个人 token 错误、过期、被禁用，或复制时多了空格。重新复制管理员发放的 token。

### 403 或 budget exceeded

个人 token 额度、过期时间、RPM 或 TPM 限制触发。联系管理员调整配额。

### model not found

模型名写错，或个人 token 没有权限访问该模型。使用管理员提供的模型名。

### provider authentication failed

通常是网关上游供应商 key 没配置或失效。这不是员工本地问题，联系管理员处理。

### 连接超时

确认是否已经连接公司 VPN，或当前网络是否在网关 IP 白名单内。

### Claude Code 使用非 Claude 模型不稳定

DeepSeek、Gemini 等模型可以通过网关做格式转换，但 Claude Code 的部分高级能力更偏向 Claude 原生协议。若遇到工具调用、token 统计或 beta header 问题，先加：

```bash
export CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS=1
```

仍不稳定时，请切换到管理员提供的 Claude 模型，或把报错发给管理员。

## 安全要求

- 不要把个人 token 写进代码仓库。
- 不要把 token 发给其他同事共用。
- token 泄露后立即联系管理员吊销。
- 离职、转岗或项目结束后，应由管理员回收 token。
- 不要绕过公司网关直接使用上游供应商 key。
