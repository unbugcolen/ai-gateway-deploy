# Langfuse 自建部署

这个目录提供一套低成本单机 Langfuse v3 Docker Compose，用于给 LiteLLM 做使用记录、trace、慢请求和错误请求分析。

## 先说结论

如果只是 23 人团队、先记录 LiteLLM metadata trace，且不涉及敏感数据出境限制，**Langfuse Cloud Core 通常更省心**。Core 当前为 `$29/月`，含 `100k units/月`，超额 `$8/100k units`。

如果公司不允许 trace 元数据出公网，或者已经有闲置服务器，**自建更合适**。自建软件免费，但要承担服务器、磁盘、备份、升级和排障成本。

| 方案 | 直接现金成本 | 运维成本 | 适合场景 |
| --- | ---: | --- | --- |
| Langfuse Cloud Core | `$29/月` 起 | 低 | 先试用、无人专门运维 |
| 单机自建 Docker | 服务器约 `4C/16G/100G` | 中 | 内网、低规模、可接受单点 |
| 自建高可用 | 多节点 + 托管 Postgres/ClickHouse/S3/Redis | 高 | 合规、海量 trace、强 SLA |

对你们当前规模，推荐路线：

1. 先用 Cloud Core 或单机自建跑 1 个月。
2. LiteLLM 只发送 metadata，不记录 prompt/response 正文。
3. 月底看 trace 量、磁盘增长和团队是否真的会看 Langfuse。
4. 如果 units 很低且无隐私压力，继续 Cloud；如果隐私/合规更重要，再长期自建。

## 架构

Langfuse v3 自建不再是单容器，至少包含：

- `langfuse-web`：Web UI 和 API。
- `langfuse-worker`：异步处理事件。
- `postgres`：账号、项目、配置等事务数据。
- `clickhouse`：trace、observation、score 等高频观测数据。
- `redis`：队列、缓存、限流。
- `minio`：S3 兼容对象存储。

## 本地启动

```bash
cd /Users/colen/code/project/mindMatrix/ai-gateway-deploy/langfuse-self-host
cp .env.example .env
```

生成密钥：

```bash
openssl rand -base64 32
openssl rand -base64 32
openssl rand -hex 32
```

把生成值分别填到 `.env`：

```env
NEXTAUTH_SECRET=第一条-base64
SALT=第二条-base64
ENCRYPTION_KEY=第三条-64位hex
```

同时替换：

```env
POSTGRES_PASSWORD=...
CLICKHOUSE_PASSWORD=...
REDIS_AUTH=...
MINIO_ROOT_PASSWORD=...
LANGFUSE_S3_SECRET_ACCESS_KEY=...
```

注意：`MINIO_ROOT_PASSWORD` 和 `LANGFUSE_S3_SECRET_ACCESS_KEY` 必须保持一致。

启动：

```bash
docker compose up -d
docker compose logs -f langfuse-web
```

打开：

```text
http://localhost:3001
```

首次进入 UI 后创建账号、组织、项目，然后在项目里创建 Langfuse API Key。

## 生产部署

生产建议：

- 服务器最低 `4C/16G/100G`。
- `LANGFUSE_WEB_BIND=127.0.0.1` 保持默认。
- 用 Nginx/Caddy 暴露 HTTPS 域名，例如 `https://langfuse.example.com`。
- 只开放 443，不直接开放 Postgres、ClickHouse、Redis、MinIO。
- 定期备份 Docker volumes，尤其是 Postgres、ClickHouse、MinIO。

生产 `.env` 示例：

```env
LANGFUSE_WEB_BIND=127.0.0.1
LANGFUSE_WEB_PORT=3001
NEXTAUTH_URL=https://langfuse.example.com
TELEMETRY_ENABLED=false
```

## LiteLLM 接入

在 Langfuse UI 中创建项目 API Key 后，把 key 写入 LiteLLM 的 `.env.litellm`：

```env
LANGFUSE_PUBLIC_KEY=pk-lf-...
LANGFUSE_SECRET_KEY=sk-lf-...
LANGFUSE_HOST=https://langfuse.example.com
```

然后把下面配置合并到 LiteLLM 的 `litellm_settings`：

```yaml
success_callback: ["langfuse"]
failure_callback: ["langfuse"]
turn_off_message_logging: true
redact_user_api_key_info: true
```

重启 LiteLLM：

```bash
docker compose -f ../litellm-hybrid-router/docker-compose.litellm.yml up -d
```

## 成本判断

低成本不是只看服务器价格。

| 成本项 | Cloud | 自建 |
| --- | --- | --- |
| 软件订阅 | 有 | 无 |
| 服务器 | 无 | 有 |
| 存储增长 | 已包含在套餐/超额里 | 自己承担 |
| 备份 | 平台负责 | 自己做 |
| 升级 | 平台负责 | 自己做 |
| 故障排查 | 平台支持 | 自己排 |
| 数据不出公网 | 取决于 Cloud 区域和合规 | 可控 |

我的建议：

- 只想省事：`Langfuse Cloud Core`。
- 有隐私要求或已有闲置服务器：`单机自建 Docker`。
- trace 量很大、要求高可用：不要用单机 compose，直接走 Helm/Terraform 或托管 ClickHouse/Postgres。

## 常用命令

```bash
# 查看状态
docker compose ps

# 查看日志
docker compose logs -f langfuse-web langfuse-worker

# 停止
docker compose down

# 升级镜像
docker compose pull
docker compose up -d

# 危险：会删除所有本地数据卷
docker compose down -v
```
