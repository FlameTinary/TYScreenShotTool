# TShot AI 后端

本目录包含 Sprint 53.5-53.6 的海外 AI Pro 路径后端 MVP。

## 范围

- Cloudflare Worker API 网关，用于 AI Pro 后端检查。
- Supabase 架构：用户、会话、订阅、用量、配额和滥用事件。
- OpenAI Responses API 转发：面向已订阅且有剩余配额的海外用户。
- 成功调用 AI 后的用量记录和月度配额递增。
- 已实现 Sign in with Apple 验证：JWT 签名验证（RS256）+ 用户创建与会话管理。
- 已实现 App Store 订阅收据验证：StoreKit signedTransaction JWT 签名验证 + 订阅记录 UPSERT。
- 已实现 App Store Server 通知（webhook）：JWT 签名验证 + 订阅状态同步。

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
- `AI_PROVIDER`：AI Provider 类型，默认 `openai`；`deepseek` / `openai-compatible` 走 Chat Completions API。
- `AI_MODEL`：AI 模型名称；当前默认配置为 `gpt-4.1-mini`。
- `OPENAI_BASE_URL`：AI Provider API 根地址；当前默认配置为 `https://api.openai.com`。
- `AI_MAX_OUTPUT_TOKENS`：每次请求的最大输出 token 数。
- `APPLE_BUNDLE_ID`：Apple 登录、StoreKit 交易和 App Store Server Notifications 校验使用的 Bundle ID，当前为 `com.sheldon.TShot`。
- `APPLE_APP_ID`：App Store Connect 中的 Apple App ID；生产环境 StoreKit / 通知 JWS 校验需要，Sandbox 可为空。
- `ALLOW_LOCAL_STOREKIT_TRANSACTIONS`：仅本地开发 / 临时测试使用。设为 `true` 或 `1` 时允许 Xcode / LocalTesting StoreKit 交易写入订阅；生产环境必须保持未设置或 `false`。

密钥必须通过 Wrangler 设置，不可提交：

```bash
# 输入: https://your-project.supabase.co
npx wrangler secret put SUPABASE_URL
# 输入: your-service-role-key
npx wrangler secret put SUPABASE_SERVICE_ROLE_KEY
# 输入: sk-your-api-key
npx wrangler secret put OPENAI_API_KEY
# 输入: 从 Apple PKI 下载的 Apple Root CA PEM，可包含多个 -----BEGIN CERTIFICATE----- 区块
npx wrangler secret put APPLE_ROOT_CERTIFICATES_PEM
```

Apple Root CA 获取方式：

1. 打开 [Apple PKI](https://www.apple.com/certificateauthority/)
2. 下载 Apple Root Certificates 区域中当前根证书
3. 转换为 PEM 后合并写入 `APPLE_ROOT_CERTIFICATES_PEM`

## 切换大模型

Worker 通过 `backend/worker/wrangler.jsonc` 中的运行时变量切换 AI Provider 和模型。修改后需要重新生成类型并部署：

```bash
cd backend/worker
npx wrangler types
npx wrangler deploy
```

如果切换到新的服务商，还需要更新 `OPENAI_API_KEY`。密钥名称保持不变，但值应替换为目标服务商的 API Key：

```bash
cd backend/worker
npx wrangler secret put OPENAI_API_KEY
```

### OpenAI 图片分析模型

用于正式截图分析时，优先选择支持图片输入的 OpenAI 模型：

```jsonc
{
  "vars": {
    "AI_PROVIDER": "openai",
    "AI_MODEL": "gpt-4.1-mini",
    "OPENAI_BASE_URL": "https://api.openai.com"
  }
}
```

说明：

- `AI_PROVIDER=openai` 会使用 OpenAI Responses API。
- `AI_MODEL` 必须是支持图片输入的模型。
- `OPENAI_API_KEY` 必须设置为 OpenAI API Key。

### OpenAI-compatible 视觉模型

如果使用第三方 OpenAI-compatible 服务，并且该服务支持 Chat Completions 的 `image_url` 图片输入：

```jsonc
{
  "vars": {
    "AI_PROVIDER": "openai-compatible",
    "AI_MODEL": "your-vision-model-name",
    "OPENAI_BASE_URL": "https://your-provider-api-root"
  }
}
```

说明：

- Worker 会请求 `${OPENAI_BASE_URL}/v1/chat/completions`。
- 请求体会携带文本 prompt 和 `image_url`。
- 目标模型必须支持图片输入；纯文本模型会调用失败。
- `OPENAI_API_KEY` 必须设置为该第三方服务商的 API Key。

### DeepSeek 纯文本配置

如仅验证文字分析，可临时切换到 DeepSeek：

```jsonc
{
  "vars": {
    "AI_PROVIDER": "deepseek",
    "AI_MODEL": "deepseek-v4-flash",
    "OPENAI_BASE_URL": "https://api.deepseek.com"
  }
}
```

说明：

- `OPENAI_API_KEY` 仍然必须设置，值为 DeepSeek API Key。
- DeepSeek 当前接口按文本模型处理，不支持截图图片输入；`/v1/ai/analyze-screenshot` 会返回 `ai_provider_input_unsupported`。
- 正式截图 AI Pro 必须使用支持图片输入的 provider/model，例如默认的 `AI_PROVIDER=openai` + `AI_MODEL=gpt-4.1-mini`。

### 切换后验证

部署后先验证鉴权和用量接口：

```bash
curl -i -H "Authorization: Bearer YOUR_TOKEN" \
  https://tshot-ai-backend.tshot.workers.dev/v1/usage/current
```

再验证截图分析接口：

```bash
curl -i -X POST https://tshot-ai-backend.tshot.workers.dev/v1/ai/analyze-screenshot \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "request_id": "model-switch-test-001",
    "image_base64": "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==",
    "prompt": "请用一句话描述这张图片"
  }'
```

常见结果：

- `200`：模型调用成功，返回截图分析结果，并计入用量。
- `401 unauthorized`：Bearer token 无效或会话不存在。
- `403 region_unavailable`：当前 storefront 不允许使用 server AI。
- `402 subscription_required`：用户没有有效订阅。
- `422 ai_provider_input_unsupported`：当前 Provider 不支持截图图片输入。
- `502 ai_provider_failed`：Provider 调用失败，通常需要检查模型名、API Key、余额、Base URL 或服务商是否支持当前请求格式。

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

## 生产环境配置
在 Cloudflare Dashboard 中检查变量与密钥：

1. 登录 [Cloudflare Dashboard](https://dash.cloudflare.com)
2. 进入 Workers & Pages → tshot-ai-backend
3. 点击 Settings → Variables and Secrets
4. 确认以下运行时变量：
   - AI_PROVIDER
   - AI_MODEL
   - OPENAI_BASE_URL
   - APPLE_BUNDLE_ID
   - APPLE_APP_ID
   - ALLOWED_STOREFRONTS
   - MONTHLY_REQUEST_LIMIT
   - DAILY_REQUEST_LIMIT
   - MAX_IMAGE_BYTES
5. 确认以下密钥：
   - SUPABASE_URL
   - SUPABASE_SERVICE_ROLE_KEY
   - OPENAI_API_KEY
   - APPLE_ROOT_CERTIFICATES_PEM
6. 在 App Store Connect 中将 App Store Server Notifications V2 URL 配置为：
   - `https://tshot-ai-backend.tshot.workers.dev/v1/apple/notifications`
7. 确认 App 侧 `settings.backendBaseURL` 未被本地覆盖，或明确指向当前 Worker：

```bash
defaults delete com.sheldon.TShot settings.backendBaseURL
# 或
defaults write com.sheldon.TShot settings.backendBaseURL -string "https://tshot-ai-backend.tshot.workers.dev"
```

## API MVP

- `GET /health`
- `POST /v1/auth/apple`：Apple Sign In 登录，传入 `identity_token`（Apple JWT），返回 `token` 和 `user_id`
- `POST /v1/subscriptions/verify`：需要 Bearer token，传入 `signed_transaction`（StoreKit JWT），验证后创建或更新订阅记录并返回订阅状态
- `GET /v1/subscriptions/status`：需要 Bearer token，地区允许
- `GET /v1/usage/current`：需要 Bearer token，地区允许
- `POST /v1/ai/analyze-screenshot`：需要 Bearer token、地区允许、有效订阅、可用配额、唯一的 `request_id`、有效的图片载荷；返回 AI 分析结果并记录用量
- `POST /v1/ai/analyze-text`：需要 Bearer token、地区允许、有效订阅、可用配额、唯一的 `request_id`、`prompt`（可选）；返回 AI 文字分析结果并记录用量
- `POST /v1/apple/notifications`：App Store Server 通知 webhook，验证 signedPayload JWT，更新订阅状态，始终返回 200

## Supabase

迁移文件路径：`backend/supabase/migrations/202606280001_ai_backend_mvp.sql`、`backend/supabase/migrations/202606300001_allow_local_storekit_subscription_environment.sql`

该架构为所有基础表启用了行级安全（RLS）。Worker 使用来自 Cloudflare 密钥的 Supabase 服务角色密钥，因此在 MVP 阶段，终端用户客户端不应获得直接的表访问权限。

成功调用 AI 后会插入 `usage_records` 记录，并调用 `increment_monthly_quota` 更新当月的配额行。重复的 `request_id` 值会在调用 AI 之前返回 `409 duplicate_request`。
