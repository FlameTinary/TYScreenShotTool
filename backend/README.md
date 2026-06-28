# TShot AI 后端

本目录包含 Sprint 53.5-53.6 的海外 AI Pro 路径后端 MVP。

## 范围

- Cloudflare Worker API 网关，用于 AI Pro 后端检查。
- Supabase 架构：用户、会话、订阅、用量、配额和滥用事件。
- OpenAI Responses API 转发：面向已订阅且有剩余配额的海外用户。
- 成功调用 AI 后的用量记录和月度配额递增。
- 尚未实现真正的 Sign in with Apple 验证。
- 尚未实现真正的 App Store Server API 验证。

Worker 仅在通过身份验证、地区、订阅、配额、请求格式、幂等性和图片大小检查后，才会调用 AI 提供商。失败的 AI 提供商调用将记录为不可计费用量，不会增加月度配额。

## Worker

路径：`backend/worker`

常用命令：

```bash
npm install
# 运行单元测试
npm test
# 类型检查
npm run typecheck
npx wrangler types
# 部署到 Cloudflare
npx wrangler deploy
```

运行时配置：

- `ALLOWED_STOREFRONTS`：以逗号分隔的商店白名单。`CHN`、未知和缺失的商店始终被阻止。
- `MONTHLY_REQUEST_LIMIT`：默认月度 AI 请求上限。
- `DAILY_REQUEST_LIMIT`：默认每日 AI 请求上限。
- `MAX_IMAGE_BYTES`：允许的最大图片载荷大小。
- `AI_MODEL`：Responses API 模型名称。
- `AI_MAX_OUTPUT_TOKENS`：每次请求的最大输出 token 数。

密钥必须通过 Wrangler 设置，不可提交：

```bash
# 输入: https://your-project.supabase.co
npx wrangler secret put SUPABASE_URL
# 输入: your-service-role-key
npx wrangler secret put SUPABASE_SERVICE_ROLE_KEY
# 输入: sk-your-api-key
npx wrangler secret put OPENAI_API_KEY
```

可选密钥：

```bash
npx wrangler secret put OPENAI_BASE_URL
# 输入: https://your-custom-openai-endpoint.com (可选)
```

本地开发：

```bash
# 启动本地开发服务器
npx wrangler dev
```

本地服务启动后，可通过以下地址访问：

- http://localhost:8787

测试API调用：

```bash
# 健康检查
curl http://localhost:8787/health

# 获取用量（需要 Bearer Token）
curl -H "Authorization: Bearer YOUR_TOKEN" \
  http://localhost:8787/v1/usage/current

# AI 截图分析（需要完整认证链）
curl -X POST http://localhost:8787/v1/ai/analyze-screenshot \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "request_id": "test-req-001",
    "image_base64": "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==",
    "prompt": "分析这个截图"
  }'
```

## 生产环境密钥配置
在 Cloudflare Dashboard 中配置密钥：

1. 登录 [Cloudflare Dashboard](https://dash.cloudflare.com)
2. 进入 Workers & Pages → tshot-ai-backend
3. 点击 Settings → Variables and Secrets
4. 添加以下环境变量：
   - SUPABASE_URL
   - SUPABASE_SERVICE_ROLE_KEY
   - OPENAI_API_KEY
   - OPENAI_BASE_URL （可选）

## API MVP

- `GET /health`
- `POST /v1/auth/apple`：占位接口，返回 `501 auth_not_implemented`
- `POST /v1/subscriptions/verify`：占位接口，返回 `501 subscription_verify_not_implemented`
- `GET /v1/subscriptions/status`：需要 Bearer token，地区允许
- `GET /v1/usage/current`：需要 Bearer token，地区允许
- `POST /v1/ai/analyze-screenshot`：需要 Bearer token、地区允许、有效订阅、可用配额、唯一的 `request_id`、有效的图片载荷；返回 AI 分析结果并记录用量
- `POST /v1/apple/notifications`：占位接口，返回 `202`

## Supabase

迁移文件路径：`backend/supabase/migrations/202606280001_ai_backend_mvp.sql`

该架构为所有基础表启用了行级安全（RLS）。Worker 使用来自 Cloudflare 密钥的 Supabase 服务角色密钥，因此在 MVP 阶段，终端用户客户端不应获得直接的表访问权限。

成功调用 AI 后会插入 `usage_records` 记录，并调用 `increment_monthly_quota` 更新当月的配额行。重复的 `request_id` 值会在调用 AI 之前返回 `409 duplicate_request`。
