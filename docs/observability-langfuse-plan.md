# 使用记录与 Langfuse 接入方案

结论：建议接，但不要把 Langfuse 当成唯一的计费系统。

这套网关里更合理的分工是：

| 系统 | 负责什么 | 是否作为月度扣费依据 |
| --- | --- | --- |
| LiteLLM | 员工 key、预算、模型权限、token/成本统计、限流 | 是，作为主数据源 |
| New API | DeepSeek / Qwen / Kimi 渠道状态、渠道错误、下游供应商余额 | 否，只辅助核对 |
| Langfuse | LLM trace、慢请求、错误请求、提示词质量、调试与评估 | 否，只做观测和分析 |
| Loki / ELK / CloudWatch | Docker、Nginx、系统日志、审计登录日志 | 否，只做运维排障 |

## 推荐接入方式

20 人团队建议分两阶段：

| 阶段 | 做法 | 目的 |
| --- | --- | --- |
| 第一阶段 | LiteLLM 接 Langfuse，但关闭 prompt/response 正文日志 | 先看清谁在用、用了什么模型、花了多少钱、哪里慢 |
| 第二阶段 | 只给测试 key 或指定服务打开完整 trace | 排查具体 prompt、工具调用、上下文过长等问题 |

生产默认建议：

- 开启 LiteLLM 的使用记录和成本统计。
- 开启 Langfuse metadata trace。
- 不记录 prompt/response 正文。
- 不记录员工原始 token 或完整 key 关联信息。
- New API 管理后台不要开放给普通员工。

## LiteLLM 配置

Langfuse 不一定要用官方云。可选方式有三种：

| 部署方式 | `LANGFUSE_HOST` 示例 | 适合场景 |
| --- | --- | --- |
| Langfuse Cloud | `https://cloud.langfuse.com` | 快速试用，少运维 |
| 公司自建域名 | `https://langfuse.example.com` | 生产推荐，便于 HTTPS、SSO、防火墙和备份 |
| 本地/内网 Docker | `http://host.docker.internal:3000` 或 `http://langfuse-web:3000` | 本地验证、内网测试 |

注意：如果 LiteLLM 运行在容器里，`LANGFUSE_HOST=http://localhost:3000` 通常是错的，因为这个 `localhost` 指的是 LiteLLM 容器自己，不是宿主机。Docker Desktop 本地测试用 `host.docker.internal`；同一个 Docker 网络里用 Langfuse Web 的服务名。

在 `litellm-hybrid-router/.env.litellm` 中增加：

```env
# Langfuse 项目的 public key。
LANGFUSE_PUBLIC_KEY=pk-你的-langfuse-public-key

# Langfuse 项目的 secret key，只给 LiteLLM 容器使用。
LANGFUSE_SECRET_KEY=sk-你的-langfuse-secret-key

# Langfuse 地址。
# 使用 Langfuse Cloud 可填 https://cloud.langfuse.com。
# 自建 Langfuse 可填 https://langfuse.example.com。
LANGFUSE_HOST=https://cloud.langfuse.com
```

然后把下面片段合并到 `litellm-hybrid-router/litellm-config.yaml` 的 `litellm_settings` 下：

```yaml
litellm_settings:
  success_callback: ["langfuse"]
  failure_callback: ["langfuse"]
  turn_off_message_logging: true
  redact_user_api_key_info: true
```

项目里已经提供独立片段：

```text
litellm-hybrid-router/litellm-observability.langfuse.snippet.yaml
```

说明：Langfuse 官方也提供基于 `langfuse_otel` 的接入方式；本项目默认先使用 LiteLLM Proxy 原生 `success_callback: ["langfuse"]`，因为 LiteLLM 对 `turn_off_message_logging` 和 `redact_user_api_key_info` 的隐私开关说明更直接。后续如果运维统一走 OpenTelemetry Collector，再单独增加 OTEL 片段。

重启 LiteLLM：

```bash
cd /opt/ai-gateway/litellm-hybrid-router
docker compose -f docker-compose.litellm.yml up -d
```

## 服务端请求标记

员工通过 Claude Code / Cursor 直接使用时，主要依赖 LiteLLM virtual key 归因。

业务服务接 LiteLLM 时，建议在请求里带 metadata，方便 Langfuse 和 LiteLLM 追踪：

```json
{
  "model": "gpt-4.1",
  "messages": [
    {
      "role": "user",
      "content": "..."
    }
  ],
  "metadata": {
    "trace_id": "业务请求ID",
    "trace_user_id": "内部用户ID",
    "tags": ["service:mp-bot", "env:prod"]
  }
}
```

如果业务系统本身已经有链路追踪，也可以把 LiteLLM 返回的 `x-litellm-call-id` 写入业务日志，后续能按请求 ID 反查。

## 保留周期建议

| 数据 | 建议保留 | 说明 |
| --- | --- | --- |
| LiteLLM spend/key 统计 | 12 个月 | 月度预算和员工使用复盘 |
| New API 渠道错误日志 | 30-90 天 | 排查供应商、渠道池和余额问题 |
| Langfuse metadata trace | 90 天 | 排查慢请求、失败请求和模型选择问题 |
| Langfuse prompt/response 正文 | 7-30 天 | 默认不开；只在测试环境或调试 key 开 |
| Docker/Nginx/系统日志 | 14-30 天 | 运维排障即可 |

## 什么时候不接 Langfuse

如果只关心“每个人花了多少钱”，LiteLLM 自带的 spend/key 统计已经够用。

如果团队没有人会定期看 trace、做慢请求分析或 prompt 质量复盘，Langfuse 会变成额外运维负担。

如果请求里会包含客户隐私、内部代码、密钥、合同、财务数据，而公司又不允许把这些内容送到外部 SaaS，就必须保持 `turn_off_message_logging: true`，或改为自建 Langfuse。
