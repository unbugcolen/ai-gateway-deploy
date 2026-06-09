# 20 人团队 AI Gateway 权限、预算与成本预测方案

适用架构：

```text
LiteLLM
 ├─ Claude 官方 API
 ├─ Gemini 官方 API
 ├─ OpenAI 官方 API
 └─ New API
     ├─ DeepSeek
     ├─ Qwen
     └─ Kimi
```

目标：让 20 人团队可以稳定使用 Claude Code、Cursor BYOK、Codex/OpenAI-compatible SDK，同时把月成本控制在可预期范围内，判断最终更可能落在 **5000、8000 还是 12000 元/月**。

## 结论

建议先按 **8000 元/月档** 启动。

- 硬预算上限：约 **1115 USD/月**，按 1 USD = 6.78 CNY 约 **7560 元/月**。
- 预留公共池：约 **150 USD/月**，用于临时提额、CI、应急任务。
- 总控制线：约 **1265 USD/月**，约 **8577 元/月**。
- 如果 2 周内 Claude Sonnet 占比超过 55%，月成本会靠近 **12000 元/月**。
- 如果严格要求普通开发默认走 DeepSeek/Qwen/Kimi，Claude 只给高风险任务使用，月成本可压到 **5000 元/月**附近。

## 价格口径

以下价格按 2026-06-09 可见官方文档或官方文档索引估算。所有价格均为每 100 万 tokens。

| 模型/渠道 | 输入价 | 输出价 | 本方案用途 | 价格来源 |
| --- | ---: | ---: | --- | --- |
| Claude Sonnet 4.5 | 3.00 USD | 15.00 USD | Claude Code 主力、高风险编码 | https://docs.claude.com/en/docs/about-claude/pricing |
| Claude Haiku 4.5 | 1.00 USD | 5.00 USD | 快速问答、轻量任务、低成本 Claude 兼容 | https://docs.claude.com/en/docs/about-claude/pricing |
| GPT-5.5 | 5.00 USD | 30.00 USD | 高阶复杂编码、专业任务、临时提额 | https://developers.openai.com/api/docs/models/gpt-5.5/ |
| GPT-4.1 | 2.00 USD | 8.00 USD | Cursor BYOK、普通 GPT 直连、工具调用 | https://developers.openai.com/api/docs/models/gpt-4.1 |
| GPT-4o | 2.50 USD | 10.00 USD | 通用多模态/兼容备用 | https://platform.openai.com/docs/models/gpt-4o |
| Gemini Pro 档 | 约 2.00 USD | 约 12.00 USD | 长上下文、多模态、备用高级模型 | https://ai.google.dev/gemini-api/docs/pricing |
| DeepSeek V4 Flash | 0.14 USD cache miss | 0.28 USD | 低成本编码、普通问答、批量任务 | https://api-docs.deepseek.com/quick_start/pricing |
| Qwen Plus | 0.40 USD | 1.20 USD | 国内模型主力、普通研发任务 | https://www.alibabacloud.com/help/en/model-studio/model-pricing |
| Kimi moonshot-v1-8k | 0.20 USD | 2.00 USD | 中文长文、产品/运营场景 | https://platform.kimi.ai/docs/pricing/chat-v1 |
| Kimi moonshot-v1-128k | 2.00 USD | 5.00 USD | 长上下文阅读，不作为默认模型 | https://platform.kimi.ai/docs/pricing/chat-v1 |

估算使用汇率：**1 USD = 6.78 CNY**。正式预算建议每月按财务结算汇率重算一次。

## 角色与模型权限

权限原则：

- Claude Sonnet 只给高风险研发、架构、复杂 debug 默认可用。
- GPT 直连作为高阶备用：`gpt-5.5` 只给管理员/高级研发或临时提额；`gpt-4.1` 可给 Cursor BYOK 和普通研发作为 GPT 默认直连模型。
- Claude Haiku 给所有人，作为 Claude 兼容的低成本模型。
- DeepSeek/Qwen/Kimi 通过 New API 管渠道池，给大多数人默认可用。
- Gemini Pro 只给需要长上下文、多模态、复杂分析的人。
- Kimi long context 只给架构、产品、QA 负责人，避免大上下文误用。

| 组别 | 人数 | 默认模型 | 可选模型 | 禁止/限制 |
| --- | ---: | --- | --- | --- |
| 架构/管理员 | 2 | `claude-sonnet-4-5` | `gpt-5.5`, `gpt-4.1`, `claude-haiku-4-5`, `gemini-2.5-pro`, `deepseek-reasoner`, `qwen-coder-plus`, `kimi-long-context` | 要求日报看用量 |
| 技术负责人/高级研发 | 4 | `claude-sonnet-4-5` | `gpt-5.5`, `gpt-4.1`, `claude-haiku-4-5`, `deepseek-chat`, `deepseek-reasoner`, `qwen-coder-plus`, `qwen-plus`, `kimi-chat`, `gemini-2.5-pro` | `gpt-5.5` 和 `kimi-long-context` 需关注用量 |
| 普通研发 | 8 | `qwen-coder-plus` | `gpt-4.1`, `claude-haiku-4-5`, `deepseek-chat`, `qwen-plus`, `kimi-chat`, `claude-sonnet-4-5` | Sonnet 每月软预算限制，不给 `gpt-5.5` |
| QA/自动化 | 3 | `deepseek-chat` | `qwen-plus`, `kimi-chat`, `claude-haiku-4-5`, `kimi-long-context` | 默认不给 Sonnet |
| DevOps/SRE | 1 | `claude-haiku-4-5` | `claude-sonnet-4-5`, `deepseek-chat`, `qwen-coder-plus`, `kimi-chat` | Sonnet 仅事故/脚本审查 |
| 产品/设计/运营 | 2 | `kimi-chat` | `qwen-plus`, `claude-haiku-4-5`, `gemini-2.5-flash` | 默认不给 Sonnet / deepseek-reasoner |

## 20 人预算配置

LiteLLM 的 `max_budget` 以 USD 计。建议 `soft_budget` 设为 `max_budget` 的 80%，触发提醒；`max_budget` 是硬上限。

| 编号 | 角色 | LiteLLM key alias | 允许模型 | 月硬预算 USD | 折合 RMB | RPM | TPM |
| --- | --- | --- | --- | ---: | ---: | ---: | ---: |
| U01 | 架构/管理员 | `u01-architect-admin` | admin-full | 100 | 678 | 120 | 200000 |
| U02 | 架构/管理员 | `u02-architect` | admin-full | 90 | 610 | 120 | 200000 |
| U03 | 技术负责人 | `u03-techlead` | senior-dev | 75 | 509 | 90 | 160000 |
| U04 | 技术负责人 | `u04-techlead` | senior-dev | 75 | 509 | 90 | 160000 |
| U05 | 高级研发 | `u05-senior-dev` | senior-dev | 75 | 509 | 90 | 160000 |
| U06 | 高级研发 | `u06-senior-dev` | senior-dev | 75 | 509 | 90 | 160000 |
| U07 | 研发 | `u07-dev` | standard-dev | 55 | 373 | 60 | 120000 |
| U08 | 研发 | `u08-dev` | standard-dev | 55 | 373 | 60 | 120000 |
| U09 | 研发 | `u09-dev` | standard-dev | 55 | 373 | 60 | 120000 |
| U10 | 研发 | `u10-dev` | standard-dev | 55 | 373 | 60 | 120000 |
| U11 | 研发 | `u11-dev` | standard-dev | 55 | 373 | 60 | 120000 |
| U12 | 研发 | `u12-dev` | standard-dev | 55 | 373 | 60 | 120000 |
| U13 | 研发 | `u13-dev` | standard-dev | 55 | 373 | 60 | 120000 |
| U14 | 研发 | `u14-dev` | standard-dev | 55 | 373 | 60 | 120000 |
| U15 | QA/自动化 | `u15-qa` | qa | 35 | 237 | 45 | 90000 |
| U16 | QA/自动化 | `u16-qa` | qa | 35 | 237 | 45 | 90000 |
| U17 | QA/自动化 | `u17-qa` | qa | 35 | 237 | 45 | 90000 |
| U18 | DevOps/SRE | `u18-sre` | sre | 55 | 373 | 60 | 120000 |
| U19 | 产品/设计 | `u19-product` | product | 25 | 170 | 30 | 60000 |
| U20 | 产品/运营 | `u20-ops` | product | 25 | 170 | 30 | 60000 |

预算合计：**1115 USD/月**，约 **7560 RMB/月**。

建议额外保留：

| 公共池 | 用途 | 月预算 USD | 折合 RMB |
| --- | --- | ---: | ---: |
| `team-ci-service` | CI、自动化测试、批量 review | 60 | 407 |
| `team-temp-boost` | 临时提额、线上事故、专项重构 | 90 | 610 |

含公共池总上限：**1265 USD/月**，约 **8577 RMB/月**。

## 模型权限分组

| 分组 | 模型列表 |
| --- | --- |
| `admin-full` | `gpt-5.5`, `gpt-4.1`, `gpt-4o`, `claude-sonnet-4-5`, `claude-haiku-4-5`, `gemini-2.5-pro`, `gemini-2.5-flash`, `deepseek-chat`, `deepseek-reasoner`, `qwen-plus`, `qwen-coder-plus`, `kimi-chat`, `kimi-long-context` |
| `senior-dev` | `gpt-5.5`, `gpt-4.1`, `claude-sonnet-4-5`, `claude-haiku-4-5`, `gemini-2.5-pro`, `deepseek-chat`, `deepseek-reasoner`, `qwen-plus`, `qwen-coder-plus`, `kimi-chat` |
| `standard-dev` | `gpt-4.1`, `claude-sonnet-4-5`, `claude-haiku-4-5`, `deepseek-chat`, `qwen-plus`, `qwen-coder-plus`, `kimi-chat` |
| `qa` | `claude-haiku-4-5`, `deepseek-chat`, `qwen-plus`, `kimi-chat`, `kimi-long-context` |
| `sre` | `gpt-4.1`, `claude-sonnet-4-5`, `claude-haiku-4-5`, `deepseek-chat`, `qwen-coder-plus`, `kimi-chat` |
| `product` | `claude-haiku-4-5`, `gemini-2.5-flash`, `qwen-plus`, `kimi-chat` |

普通研发虽然允许 Sonnet，但要通过 key 总预算和模型软预算控制。若第一个月成本超 8000 元，第二个月把 `standard-dev` 的 Sonnet 改为申请制。

## LiteLLM key 创建模板

单人 key：

```bash
curl -X POST "$LITELLM_BASE_URL/key/generate" \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "key_alias": "u07-dev",
    "user_id": "u07",
    "models": [
      "claude-sonnet-4-5",
      "gpt-4.1",
      "claude-haiku-4-5",
      "deepseek-chat",
      "qwen-plus",
      "qwen-coder-plus",
      "kimi-chat"
    ],
    "max_budget": 55,
    "soft_budget": 44,
    "budget_duration": "30d",
    "duration": "180d",
    "rpm_limit": 60,
    "tpm_limit": 120000,
    "metadata": {
      "team": "engineering",
      "role": "standard-dev",
      "owner": "u07"
    }
  }'
```

公共 CI key：

```bash
curl -X POST "$LITELLM_BASE_URL/key/generate" \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "key_alias": "team-ci-service",
    "user_id": "service-ci",
    "models": ["claude-haiku-4-5", "deepseek-chat", "qwen-coder-plus"],
    "max_budget": 60,
    "soft_budget": 48,
    "budget_duration": "30d",
    "duration": "180d",
    "rpm_limit": 120,
    "tpm_limit": 200000,
    "metadata": {
      "team": "platform",
      "role": "service-account"
    }
  }'
```

## Cursor BYOK 接入方案

推荐接法：Cursor 只接 LiteLLM，不接 New API。

### 管理员发给员工

```text
OpenAI-compatible Base URL:
https://ai-gateway.example.com/v1

API Key:
sk-员工自己的-litellm-virtual-key

默认模型:
claude-sonnet-4-5、gpt-4.1 或 qwen-coder-plus
```

### 员工配置

1. 打开 Cursor Settings。
2. 进入 Models / API Keys。
3. 启用 OpenAI-compatible 或 OpenAI API Key。
4. API Key 填员工自己的 LiteLLM key。
5. Base URL 填 `https://ai-gateway.example.com/v1`。
6. 添加/选择模型：
   - `claude-sonnet-4-5`
   - `gpt-4.1`
   - `gpt-4o`
   - `claude-haiku-4-5`
   - `qwen-coder-plus`
   - `deepseek-chat`
   - `kimi-chat`

注意：

- Cursor 官方 BYOK 主要面向标准 chat 模型；Tab Completion 等专用功能可能仍走 Cursor 内置模型或不支持自定义 key。
- 不建议给 Cursor 直接配置 New API token，否则会绕过 LiteLLM 的员工预算和审计。
- 如果 Cursor 版本没有明显的 Base URL 输入框，优先使用 OpenAI-compatible provider；仍不支持时，Cursor 只作为官方 BYOK，团队预算改由 LiteLLM 外部日志/供应商后台审计。

## 月成本预测

### 预测口径

成本公式：

```text
月成本 = 输入 token 百万数 * 输入单价 + 输出 token 百万数 * 输出单价
```

估算时假设：

- 输出 token 约为输入 token 的 10%。
- Claude Sonnet 主要用于复杂编码、debug、架构设计。
- DeepSeek/Qwen/Kimi 承担大多数普通任务。
- 未计入税费、供应商充值折扣、New API 渠道倍率、缓存命中优惠。

### 三档预测

| 档位 | 使用画像 | Sonnet 用量 | 轻量官方模型用量 | New API 便宜模型用量 | 估算 USD | 估算 RMB | 判断 |
| --- | --- | --- | --- | --- | ---: | ---: | --- |
| 5000 档 | 普通研发默认 Qwen/DeepSeek，Sonnet 仅高风险任务 | 55M 输入 / 5.5M 输出 | 50M 输入 / 5M 输出 | 650M 输入 / 65M 输出 | 707 | 4793 | 可达到，但要强管 Sonnet |
| 8000 档 | 推荐策略，核心研发用 Sonnet，普通任务走 New API | 115M 输入 / 11.5M 输出 | 80M 输入 / 8M 输出 | 850M 输入 / 85M 输出 | 1146 | 7770 | 最可能落点 |
| 12000 档 | Cursor/Claude Code 重度使用，普通研发大量 Sonnet | 210M 输入 / 21M 输出 | 120M 输入 / 12M 输出 | 1000M 输入 / 100M 输出 | 1762 | 11946 | 高强度研发月会接近 |

### 按角色预测

| 角色 | 人数 | 人均预期 USD | 小计 USD | 说明 |
| --- | ---: | ---: | ---: | --- |
| 架构/管理员 | 2 | 70 | 140 | Sonnet 占比高，但人数少 |
| 技术负责人/高级研发 | 4 | 58 | 232 | Sonnet + qwen-coder 混用 |
| 普通研发 | 8 | 42 | 336 | 默认 qwen-coder/deepseek，复杂问题用 Sonnet |
| QA/自动化 | 3 | 22 | 66 | DeepSeek/Qwen/Kimi 为主 |
| DevOps/SRE | 1 | 38 | 38 | 事故时使用 Sonnet |
| 产品/设计/运营 | 2 | 16 | 32 | Kimi/Qwen/Haiku 为主 |
| 公共池 | - | - | 150 | CI、临时提额、事故 |
| 预留波动 | - | - | 152 | 税费、汇率、缓存未命中、异常用量 |
| 合计 | 20 | - | 1146 | 约 7770 RMB |

## 判断 5000 / 8000 / 12000 的监控指标

上线前两周每天看 LiteLLM spend：

| 指标 | 5000 档信号 | 8000 档信号 | 12000 档信号 |
| --- | --- | --- | --- |
| Sonnet 成本占比 | < 35% | 35% - 55% | > 55% |
| 普通研发人均日成本 | < 1.3 USD | 1.3 - 2.2 USD | > 2.2 USD |
| 全团队日成本 | < 23 USD | 23 - 40 USD | > 40 USD |
| New API 模型 token 占比 | > 70% | 50% - 70% | < 50% |
| Cursor BYOK 使用人数 | < 8 | 8 - 14 | > 14 且全天使用 |

实际判定：

- 连续 7 天日均成本低于 23 USD：月成本大概率 **5000 元左右**。
- 连续 7 天日均成本 23 - 40 USD：月成本大概率 **8000 元左右**。
- 连续 7 天日均成本高于 40 USD：月成本大概率 **12000 元左右**。

## 成本控制策略

第一阶段，默认策略：

- 架构/负责人：允许 Sonnet。
- 普通研发：允许 Sonnet，但通过 55 USD 月预算限制。
- QA/产品：默认不给 Sonnet。
- Cursor BYOK：只发 LiteLLM key，禁止直连 New API。

第二阶段，如果超过 8000：

- `standard-dev` 移除 `claude-sonnet-4-5`，改为临时申请。
- `deepseek-reasoner` 只给 senior-dev/admin。
- `kimi-long-context` 只给 admin/qa 负责人。
- 每人预算整体下调 15%。

第三阶段，如果仍超过 12000：

- 建立 Sonnet 临时提额流程，按任务申请 24h key。
- Cursor 默认模型改 `qwen-coder-plus`。
- Claude Code 默认模型保留 Sonnet，但只给核心研发。
- CI 和批量任务全部使用 `claude-haiku-4-5`、`deepseek-chat`、`qwen-coder-plus`。

## 建议落地顺序

1. 按本文预算创建 20 个 LiteLLM virtual key。
2. New API 创建一个服务 token，只开放 DeepSeek/Qwen/Kimi。
3. Cursor 和 Claude Code 只发 LiteLLM key。
4. 第一周每天看 LiteLLM spend。
5. 第二周按 Sonnet 占比决定是否收紧普通研发权限。
6. 一个月后用真实 spend 重算模型配比和预算。
