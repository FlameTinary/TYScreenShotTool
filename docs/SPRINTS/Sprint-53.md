# Sprint 53 - AI 订阅服务区域化底座

## Status

🚧 In Progress

## Goal

将“截图工具 AI 订阅服务区域化方案”整理为可落地的产品与技术需求，并为后续海外 AI Pro 商业化建立第一层区域化底座。

本 Sprint 的核心目标不是一次性完成登录、订阅、后端和 AI 转发，而是先明确产品边界、合规边界、工程切分和验收标准，确保后续每个 Feature 都能独立开发、验证和回滚。

---

## Background

当前 TShot 已具备截图、标注、OCR、本地翻译、隐藏 AI 入口和实验性 AI 分析能力。

现有 AI 能力特点：

- `AI` 入口默认隐藏，可在 Settings 中手动显示
- AI 请求依赖本地隐藏配置 `defaults write`
- AI API Key 当前可写入本机配置，仅适合开发者或实验性使用
- 本地「翻译」入口与 AI 链路解耦，不调用后端，不调用 AI 服务

后续如果面向真实用户提供 AI 分析订阅服务，需要避免将中国大陆地区卷入账号、联网、订阅、AI 服务合规和截图上传风险。

因此本 Sprint 采用区域化产品策略：

```text
中国大陆：
纯本地截图工具
不显示 AI 商业入口
不显示登录
不显示订阅
不请求后端
不上传截图

中国大陆以外：
基础能力免费
AI Pro 作为订阅能力
使用 Sign in with Apple
使用 Apple 自动续期订阅
使用 serverless 后端校验订阅、地区、额度和风控
```

---

## Product Requirements

### 1. 中国大陆区产品要求

中国大陆区定位为纯本地截图工具。

必须保留：

- 普通截图
- 长截图
- 标注编辑
- 复制
- 保存
- Pin
- 本地 OCR
- 本地翻译
- 多语言
- 外观切换
- 现有基础设置项

必须关闭或隐藏：

- AI 分析入口
- AI 总结入口
- AI 翻译入口
- AI Pro 入口
- 登录入口
- 注册入口
- 订阅入口
- 后端配置入口
- AI API Key 配置入口
- 商业 AI 请求链路
- 远程配置请求

必须满足：

- 大陆模式下不请求海外后端
- 大陆模式下不请求 AI 服务商接口
- 大陆模式下不上传截图内容
- 大陆 App Store 文案、截图、关键词不宣传 AI 能力
- 大陆用户即使手动打开历史 `showAIEntrances` 设置，也不能绕过区域策略使用商业 AI

### 2. 海外区产品要求

海外区采用基础免费 + AI Pro 订阅模式。

免费用户：

- 可继续使用基础截图能力
- 可看到 AI Pro 能力介绍入口
- 可进入订阅页
- 未订阅时不能调用 AI 后端
- 未订阅时不能产生 AI API 成本

订阅用户：

- 可使用 AI 分析
- 可使用 AI 总结
- 可使用 AI 翻译
- 可使用图片理解类能力
- 每月拥有固定 AI 使用额度
- 超额后展示明确提示，不继续调用 AI API

第一版海外 AI Pro 只支持：

- 一个登录方式：Sign in with Apple
- 一个订阅商品：AI Pro Monthly
- 一个 AI 服务后端：Cloudflare Workers
- 一个数据存储：Supabase
- 一个固定月额度策略
- 一个模型供应商

暂不支持：

- 中国大陆 AI 服务
- 中国大陆账号系统
- 中国大陆订阅
- 团队订阅
- 企业版
- 无限 AI 分析
- 多模型路由
- 自建模型
- 复杂后台管理系统

---

## Technical Requirements

### 1. App 端区域策略

App 端需要新增统一区域策略层，后续代码统一从这里判断 AI、登录、订阅和后端能力是否可用。

建议模块：

```text
RegionPolicy
- isChinaMainlandMode
- effectiveStorefront
- isNetworkFeatureAllowed
- isAICommercialFeatureAllowed

FeatureFlags
- showAIEntrances
- isLoginEnabled
- isSubscriptionEnabled
- isServerAPIEnabled
- isDeveloperLocalAIConfigEnabled

AIAvailabilityService
- currentAvailability()
- refreshStorefrontIfAllowed()
- shouldShowAIEntryPoint()
```

判断优先级：

```text
区域策略
>
订阅状态
>
用户设置
>
开发者隐藏配置
```

关键规则：

- `storefront == CHN` 时进入中国大陆模式
- 中国大陆模式下不初始化商业 AI 后端请求
- 中国大陆模式下不读取远程配置作为功能开关来源
- 中国大陆模式下 AI 商业能力硬关闭
- 海外模式下才允许展示 AI Pro、登录和订阅入口
- 客户端区域判断只负责 UI 和本地保护，最终权限以后端为准

### 2. 历史 AI 隐藏配置隔离

现有本地隐藏配置：

```text
local.aiAnalysis.baseURL
local.aiAnalysis.openAIAPIKey
local.aiAnalysis.model
```

后续定位调整为：

```text
开发者 / Debug / 内部验证能力
```

正式商业化路径必须满足：

- 不要求普通用户写入本地 AI API Key
- 不把 AI API Key 放入 App 包
- 不通过远程配置下发 AI API Key
- 不让本地隐藏配置绕过地区策略和订阅策略
- 商业 AI 请求必须走后端

### 3. StoreKit 订阅

后续 StoreKit 2 接入要求：

```text
Product ID:
tshot.pro.monthly

Type:
Auto-Renewable Subscription

Availability:
Exclude China Mainland
```

App 端负责：

- 加载订阅商品
- 展示价格、周期和自动续期说明
- 发起购买
- 恢复购买
- 监听交易更新
- 将已验证交易发送后端

后端负责：

- 使用 App Store Server API 校验交易
- 保存订阅状态
- 处理订阅过期、取消、退款、宽限期和账单重试
- AI 请求时以后端订阅状态为准

第一版应尽早支持 App Store Server Notifications V2，用于同步退款、取消、续费失败和宽限期状态。

### 4. 登录与账号

第一版只支持 Sign in with Apple。

用户绑定模型：

```text
Apple Identity
↓
Supabase Auth User
↓
App User Profile
↓
Subscription
↓
Usage Quota
```

要求：

- 不使用 email 作为唯一身份
- 使用稳定用户 ID 绑定订阅与额度
- 使用 `appAccountToken` 绑定 App 用户与 Apple 交易
- 支持跨设备恢复权益
- 支持后端封禁异常账号

### 5. Serverless 后端

推荐组合：

```text
Cloudflare Workers + Supabase
```

Cloudflare Workers 负责：

- API 网关
- 用户鉴权
- 地区校验
- 订阅校验
- AI 请求转发
- 限流
- 防刷
- 隐藏 AI API Key

Supabase 负责：

- 用户资料
- 订阅状态
- 调用额度
- 请求日志
- 滥用事件

MVP API：

```text
POST /v1/auth/apple
POST /v1/subscriptions/verify
GET  /v1/subscriptions/status
GET  /v1/usage/current
POST /v1/ai/analyze-screenshot
POST /v1/ai/analyze-text
POST /v1/apple/notifications
```

#### API 请求流程图

**Apple Sign In 登录**

```text
Client (iOS)                                        Backend
  │                                                    │
  │  POST /v1/auth/apple                               │
  │  { "identity_token": "<Apple JWT>" }               │
  │ ───────────────────────────────────────────────>    │
  │                                                     │
  │   ① 解析 JWT → header / payload / signature        │
  │   ② 从 https://appleid.apple.com/auth/keys 获取公钥  │
  │   ③ 匹配 kid → 导入公钥（RS256）                     │
  │   ④ 验证 JWT 签名                                   │
  │   ⑤ 验证 claims: iss / aud / exp                   │
  │   ⑥ 提取 sub（Apple User ID）                       │
  │   ⑦ findOrCreateUser(appleUserId, email)            │
  │   ⑧ createSession(userId) → 生成 Bearer Token      │
  │                                                     │
  │  { "token": "<bearer_token>",                       │
  │    "user_id": "<uuid>" }                            │
  │ <───────────────────────────────────────────────    │
```

**StoreKit 订阅收据验证**

```text
Client (iOS)                                        Backend
  │                                                    │
  │  POST /v1/subscriptions/verify                     │
  │  Authorization: Bearer <token>                     │
  │  { "signed_transaction": "<StoreKit JWT>" }        │
  │ ───────────────────────────────────────────────>    │
  │                                                     │
  │   ① 校验 Bearer Token → 查找用户                    │
  │   ② 解析 StoreKit JWT → header / payload           │
  │   ③ 用 Apple 公钥验证 RS256 签名                    │
  │   ④ 验证 claims: iss / aud / bundleId              │
  │   ⑤ 提取: transactionId / originalTransactionId    │
  │      productId / expiresDate / environment          │
  │   ⑥ createOrUpdateSubscription(userId, txn)        │
  │      → 按 originalTransactionId UPSERT              │
  │                                                     │
  │  { "status": "active",                              │
  │    "product_id": "tshot.pro.monthly",               │
  │    "expires_at": "2026-07-28T...",                  │
  │    "environment": "Sandbox" }                       │
  │ <───────────────────────────────────────────────    │
```

**App Store Server 通知 webhook**

```text
Apple Server                                     Backend
  │                                                 │
  │  POST /v1/apple/notifications                   │
  │  { "signedPayload": "<通知 JWT>" }               │
  │ ─────────────────────────────────────────────>   │
  │                                                  │
  │   ① 验证通知 JWT 签名（复用 Apple 公钥）           │
  │   ② 提取 notificationType                        │
  │   ③ 提取 data.signedTransactionInfo (JWT)        │
  │   ④ 验证 transactionInfo JWT 签名                 │
  │   ⑤ 根据通知类型映射订阅状态：                     │
  │      SUBSCRIBED / DID_RENEW         → active     │
  │      EXPIRED / DID_FAIL_TO_RENEW    → expired    │
  │      REFUND / REVOKE                → refunded   │
  │   ⑥ 从 transactionInfo.appAccountToken 获取用户   │
  │   ⑦ createOrUpdateSubscription(userId, txn)      │
  │                                                  │
  │  200 OK（始终返回，错误记日志不重试）               │
  │ <─────────────────────────────────────────────── │
```

### 6. AI 请求安全链路

**订阅状态查询**

```text
Client (iOS)                                        Backend
  │                                                    │
  │  GET /v1/subscriptions/status                      │
  │  Authorization: Bearer <token>                     │
  │ ───────────────────────────────────────────────>    │
  │                                                     │
  │   ① 校验 Bearer Token → 查找用户                    │
  │   ② 校验 storefront allowlist                      │
  │   ③ 查询 subscriptions 表（最新记录）                 │
  │                                                     │
  │  { "user_id": "<uuid>",                             │
  │    "status": "active",                              │
  │    "product_id": "tshot.pro.monthly",               │
  │    "expires_at": "2026-07-28T..." }                 │
  │ <───────────────────────────────────────────────    │
```

**当前用量查询**

```text
Client (iOS)                                        Backend
  │                                                    │
  │  GET /v1/usage/current                             │
  │  Authorization: Bearer <token>                     │
  │ ───────────────────────────────────────────────>    │
  │                                                     │
  │   ① 校验 Bearer Token → 查找用户                    │
  │   ② 校验 storefront allowlist                      │
  │   ③ 查询 usage_current 视图                         │
  │                                                     │
  │  { "user_id": "<uuid>",                             │
  │    "monthly_used_count": 3,                         │
  │    "monthly_limit_count": 100,                      │
  │    "daily_used_count": 1,                           │
  │    "daily_limit_count": 20 }                        │
  │ <───────────────────────────────────────────────    │
```

**截图分析请求**

```text
Client (iOS)                                        Backend
  │                                                    │
  │  POST /v1/ai/analyze-screenshot                    │
  │  Authorization: Bearer <token>                     │
  │  { "request_id": "uuid",                           │
  │    "image_base64": "<base64>",                     │
  │    "prompt": "分析这个截图" }                        │
  │ ───────────────────────────────────────────────>    │
  │                                                     │
  │   ① 校验 Bearer Token → 查找用户                    │
  │   ② 校验 storefront allowlist                      │
  │   ③ 校验 subscription active / grace_period        │
  │   ④ 校验月额度 / 日额度                              │
  │   ⑤ 校验 request_id 幂等（409 重复）                 │
  │   ⑥ 校验 image_base64 大小 ≤ 2MB                   │
  │   ⑦ 调用 AI Provider（Response / Chat API）          │
  │   ⑧ 记录 usage_records（succeeded）                  │
  │   ⑨ increment_monthly_quota                         │
  │                                                     │
  │  { "request_id": "uuid",                            │
  │    "analysis": "<AI 返回内容>",                       │
  │    "model": "deepseek-v4-flash",                    │
  │    "usage": { "input_tokens": 80,                   │
  │               "output_tokens": 24 } }               │
  │ <───────────────────────────────────────────────    │
```

失败路径：
- `401` → 无 Authorization 或用户不存在
- `403` → storefront 不在白名单（含 CHN）
- `402` → 无有效订阅
- `429` → 月额度或日额度用尽
- `409` → request_id 已存在
- `413` → 图片超过 2MB
- `422` → provider 不支持图片输入（DeepSeek 模式）
- `502` → AI provider 调用失败

**文字分析请求**

```text
Client (iOS)                                        Backend
  │                                                    │
  │  POST /v1/ai/analyze-text                          │
  │  Authorization: Bearer <token>                     │
  │  { "request_id": "uuid",                           │
  │    "prompt": "解释什么是 REST API" }                  │
  │ ───────────────────────────────────────────────>    │
  │                                                     │
  │   ① 校验 Bearer Token → 查找用户                    │
  │   ② 校验 storefront allowlist                      │
  │   ③ 校验 subscription active / grace_period        │
  │   ④ 校验月额度 / 日额度                              │
  │   ⑤ 校验 request_id 幂等（409 重复）                 │
  │   ⑥ 调用 AI Provider（纯文本，不传图片）               │
  │   ⑦ 记录 usage_records（imageBytes=0）              │
  │   ⑧ increment_monthly_quota                         │
  │                                                     │
  │  { "request_id": "uuid",                            │
  │    "analysis": "<AI 返回内容>",                       │
  │    "model": "deepseek-v4-flash",                    │
  │    "usage": { "input_tokens": 10,                   │
  │               "output_tokens": 121 } }              │
  │ <───────────────────────────────────────────────    │
```

限制建议：

```text
图片最大 2MB
图片最长边 1600px
单次请求超时 30 秒
单日最多 20 次
月度最多 100 次
输出 token 上限 1200
```

禁止：

- 未登录用户调用 AI
- 未订阅用户调用 AI
- 订阅用户无限调用 AI
- 前端判断订阅，后端不判断
- AI API Key 放在 App 本地
- 不记录调用次数
- 不限制图片大小
- 不限制 token
- 不限制单日调用次数

---

## Data Model Draft

### users

```text
id
apple_user_id
email
display_name
country_code
storefront
created_at
updated_at
```

### subscriptions

```text
id
user_id
product_id
original_transaction_id
latest_transaction_id
status
expires_at
environment
created_at
updated_at
```

### usage_records

```text
id
user_id
request_id
request_type
model
image_bytes
image_count
input_token_count
output_token_count
estimated_cost
billable
status
created_at
```

### monthly_quotas

```text
id
user_id
month
used_count
limit_count
used_tokens
limit_tokens
used_cost
limit_cost
created_at
updated_at
```

### abuse_events

```text
id
user_id
ip
reason
detail
created_at
```

---

## Feature Breakdown

### Feature 53.1：App 区域策略底座

目标：

- 新增区域策略与 AI 可用性判断
- 中国大陆模式下强制隐藏商业 AI、登录、订阅和后端请求能力
- 海外模式下允许后续展示 AI Pro 入口

验收：

- 能通过单元测试验证 `CHN` 与非 `CHN` 策略差异
- 大陆模式下 `showAIEntrances = true` 也不能展示商业 AI
- 本地 OCR、本地翻译、复制、保存、Pin 不受影响

实现记录：

- 已新增 `RegionPolicy`、`RegionPolicyResolver` 和 `AIAvailabilityService`
- `CHN` 进入中国大陆模式，商业 AI、登录、订阅和 server API 全部关闭
- 非 `CHN` 允许后续 AI Pro、登录、订阅和 server API 判断
- unknown / nil storefront 采用保守策略，默认关闭商业 AI 与 server API
- 普通截图与长截图继续通过 `AppSettings.effectiveShowAIEntrances` 判断 AI 入口，内部已切换为区域策略优先

### Feature 53.2：AI 入口与历史隐藏配置隔离

目标：

- 将当前隐藏 AI 配置明确隔离为开发者能力
- 商业 AI 可用性统一走 `AIAvailabilityService`
- 防止本地隐藏配置绕过区域策略

验收：

- 中国大陆模式下不出现 AI 商业入口
- 开发者隐藏配置不改变商业 AI 可用性
- README 与 PROJECT_CONTEXT 对 AI 能力边界说明一致

实现记录：

- `local.aiAnalysis.*` 已明确为 Debug / 开发者 / 内部验证能力
- `AIAnalysisService` 与 `AIImageTextExtractionService` 在读取 API Key、构造请求和发起网络前先经过 `AIAvailabilityService`
- `CHN` 与 unknown / nil storefront 下，即使存在本地 API Key，也会本地拦截，不触发商业 AI 网络请求
- 非 `CHN` 策略下允许进入现有开发者 API Key 校验，但仍不代表正式 AI Pro 订阅链路
- Settings Debug 文案、README 与 PROJECT_CONTEXT 已同步区域策略边界

### Feature 53.3：海外 AI Pro 壳层

目标：

- 海外区显示 AI Pro 入口
- 未登录时提示 Sign in with Apple
- 未订阅时展示订阅说明
- 本阶段不真实调用 AI 后端

验收：

- 海外模式下可以看到 AI Pro 入口
- 未订阅点击 AI 时不会产生 AI 请求
- 大陆模式下完全看不到该入口

实现记录：

- 新增 `AppRegionPolicyProvider`，Debug 下支持通过 `debug.regionPolicy.storefrontCode` 注入 storefront，便于本地验证 `USA` / `CHN` / unknown 分支
- 新增 `AIProShellAvailability`，将海外 AI Pro 壳层可见性与点击行为收口为可测试模型
- `AIAvailabilityService` 默认从 `AppRegionPolicyProvider` 获取当前区域策略，`AppSettings.effectiveShowAIEntrances` 切换为 AI Pro 壳层入口判断
- 普通截图与长截图 AI 按钮在海外 Debug 策略下展示 AI Pro 说明弹窗，不再进入真实 AI 请求菜单
- Debug Settings 新增区域策略覆盖输入，方便人工验证海外 / 大陆 / unknown 模式
- 单元测试覆盖 Debug storefront override、AI Pro 壳层可见性，以及点击壳层不转换为 AI 请求

### Feature 53.4：StoreKit 2 订阅接入

目标：

- 接入 AI Pro Monthly 自动续期订阅
- 支持购买、恢复购买、交易监听
- 将交易信息发送后端校验

验收：

- Sandbox 环境可完成购买
- 恢复购买可恢复订阅状态
- 本地 UI 不作为最终权限来源

实现记录：

- 新增 `AIProSubscriptionProductID`、`AIProSubscriptionProduct`、`AIProSubscriptionStatus` 与 `AIProSubscriptionPromptContent`，将订阅商品、状态和弹窗动作收口为可测试模型
- 新增 `AIProSubscriptionService`，封装 StoreKit 2 商品加载、购买、恢复购买和交易更新监听
- 当前只支持 `tshot.pro.monthly` / AI Pro Monthly 自动续期订阅
- 新增 `TYScreenShotTool/TShot.storekit` 本地 StoreKit 配置，并关联默认 Debug 运行 scheme
- 默认测试 scheme 也关联 `TYScreenShotTool/TShot.storekit`，便于 StoreKitTest 读取同一份本地商品配置
- AI Pro 壳层在海外策略允许时加载订阅商品，提供订阅与恢复入口；中国大陆和 unknown 模式不启动 StoreKit 监听、不加载商品
- 新增 Debug-only StoreKit 验证入口：写入 `debug.storeKitVerificationMode=load|purchase|restore` 后通过 Xcode Debug scheme 启动 App，可在控制台输出加载、购买或恢复状态，并在验证结束后自动清理该 mode
- 新增显式 opt-in 的 StoreKitTest 购买验证：`test_storeKitConfigurationCanPurchaseMonthlyProduct` 默认跳过；本机签名环境写入 `debug.runStoreKitSandboxTests=true` 后可验证 `tshot.pro.monthly` 能产生本地购买交易
- 已在本机签名环境执行 StoreKit 购买验证，结果通过；默认 `./scripts/test.sh` 会禁用签名，因此该购买验证不作为默认测试门禁
- Xcode Debug scheme 下的 Product API `load` 验证当前返回 `unavailable`，已记录为本地 StoreKit runtime 注入限制；可重复的购买交易验证以后续显式签名测试为准
- 本地订阅状态当前只用于 UI 展示，不作为最终 AI 请求权限；AI 后端、登录和额度校验仍留给后续 Feature
- 单元测试覆盖商品 ID、订阅状态、弹窗动作、订阅区域策略判断和 opt-in StoreKit 本地购买交易验证

### Feature 53.5：Serverless 后端 MVP

目标：

- 建立 Cloudflare Workers + Supabase 后端
- 完成用户、订阅、额度、日志基础表
- 完成订阅校验与用量查询 API

验收：

- API Key 只存放在后端环境变量
- 后端能校验登录态、地区和订阅状态
- 未订阅用户无法调用 AI API

实现记录：

- 新增 `backend/worker` Cloudflare Workers TypeScript MVP，使用 `wrangler.jsonc`、Vitest 和 TypeScript 类型检查
- Worker 当前提供 `GET /health`、`POST /v1/auth/apple`、`POST /v1/subscriptions/verify`、`GET /v1/subscriptions/status`、`GET /v1/usage/current`、`POST /v1/ai/analyze-screenshot`、`POST /v1/ai/analyze-text`、`POST /v1/apple/notifications` 共 8 个 API 端点
- `POST /v1/ai/analyze-screenshot` 与 `POST /v1/ai/analyze-text` 已按登录态、地区、订阅、日/月额度顺序进行前置拦截，通过后调用 AI provider 并记录用量
- `CHN`、unknown / nil storefront 和非 allowlist storefront 在后端侧默认返回 `region_unavailable`
- 新增 Supabase migration，包含 `users`、`app_sessions`、`subscriptions`、`usage_records`、`monthly_quotas`、`abuse_events`、`usage_current` 和 `user_ai_access`
- 所有 Supabase 基础表已启用 RLS；Worker 使用 Cloudflare secret 中的 Supabase service role key 访问，普通客户端不直接访问这些表
- `POST /v1/auth/apple` 已从占位推进为完整 Apple Sign In 登录：新建 `appleAuth.ts` 模块验证 Apple JWT（RS256），支持公钥缓存（TTL 1h）和 claims 验证；`BackendRepository` 新增 `findOrCreateUser` / `createSession`；`SupabaseRepository` 实现用户创建与随机 Token 会话生成
- `POST /v1/subscriptions/verify` 已从占位推进为 StoreKit 订阅收据验证：新增 `verifyStoreKitTransactionJWT` 验证 signedTransaction JWT；`createOrUpdateSubscription` 按 `originalTransactionId` UPSERT 订阅记录；支持 Sandbox / Production 自动识别
- `POST /v1/apple/notifications` 已从占位推进为 App Store Server 通知 webhook：新增 `verifyAppStoreNotificationJWT` 验证通知 JWT；`notificationTypeToStatus` 映射通知类型到订阅状态；`appAccountToken` 关联用户；始终返回 200 确认收到
- `POST /v1/ai/analyze-text` 新增纯文字分析端点，`AIProvider` 接口新增 `analyzeText()` 方法；`OpenAIResponsesProvider` 与 `OpenAICompatibleChatProvider` 分别用纯文本格式调用后端 API；文字请求不计图片字节
- 新增数据库迁移 `202606280002_add_analyze_text_request_type.sql`，扩展 `usage_records.request_type` 约束支持 `analyze_text`
- 新增 `APPLE_BUNDLE_ID` 环境变量，用于 JWT audience 验证
- 单元测试覆盖 Apple 登录缺失 token、JWT 验证失败、成功获取 token 和已存在用户登录；订阅验证无认证、缺少 signed_transaction、无效 JWT 和成功验证；通知缺失 payload、有效通知和多种通知类型映射
- 单元测试已扩展至 40 个用例（覆盖 3 个测试文件）

### Feature 53.6：AI 分析闭环与额度控制

目标：

- 订阅用户可使用 AI 分析截图
- 后端限制图片大小、token、日额度、月额度
- 记录 usage_records 并扣减 monthly_quotas

验收：

- 订阅用户可获得 AI 结果
- 未订阅或超额用户不会触发 AI API 调用
- AI 失败、超时、超额都有明确提示

实现记录：

- `POST /v1/ai/analyze-screenshot` 已从占位 `501` 推进为后端 AI 分析闭环
- 请求会先经过 Bearer 登录态、地区 allowlist、订阅 active / grace_period、日/月额度、`request_id` 幂等和图片大小校验
- 通过校验后由 `OpenAIResponsesProvider` 调用 OpenAI Responses API；`OPENAI_API_KEY` 只通过 Cloudflare secret 注入，不进入 App 包或仓库配置
- 成功结果会写入 `usage_records`，并通过 Supabase RPC `increment_monthly_quota` 扣减本月次数、token 和成本
- AI provider 失败时返回 `502 ai_provider_failed`，写入非 billable 失败记录，不扣减额度
- 重复 `request_id` 返回 `409 duplicate_request`，不会重复调用 AI provider
- 单元测试覆盖订阅海外用户成功获得 AI 结果、重复 request_id、月额度耗尽、AI provider 失败、未订阅和地区拦截路径

### Feature 53.7：App 端 Apple 登录与后端会话接入

目标：

- App 端接入 Sign in with Apple
- 使用 Apple `identityToken` 调用后端 `POST /v1/auth/apple`
- 获取并保存后端 Bearer token，作为后续订阅校验、用量查询和 AI 请求凭证

实现方案：

- 新增 App 端登录服务，例如 `AIProAuthService`：
  - 使用 `AuthenticationServices` 发起 Sign in with Apple
  - 获取 `ASAuthorizationAppleIDCredential.identityToken`
  - 将 identity token POST 到后端 `/v1/auth/apple`
  - 解析后端返回的 `token` 与 `user_id`
- 新增后端 API 客户端，例如 `AIProBackendClient`：
  - 统一管理 `baseURL`
  - 统一设置 `Authorization: Bearer <token>`
  - 统一解析后端错误码
- 新增会话存储：
  - Bearer token 使用 Keychain 保存
  - `user_id` 可保存到 UserDefaults
  - 提供 `isSignedIn`、`currentToken`、`signOut`
- AI Pro 入口点击时：
  - 先经过 `AIAvailabilityService` 区域策略
  - 中国大陆 / unknown 不触发登录
  - 海外未登录时弹出登录提示并发起 Apple 登录
- 不将 Apple identity token 或后端 Bearer token 写入日志、UserDefaults 明文或 App 包。

验收：

- 海外模式下未登录点击 AI Pro 可触发 Sign in with Apple
- 登录成功后后端返回 Bearer token，并可调用 `/v1/usage/current`
- 登录失败、用户取消、后端返回 `authentication_failed` 时有明确提示
- 中国大陆 / unknown 模式下不会发起 Apple 登录或后端请求
- 单元测试覆盖登录状态模型、token 存储包装、后端错误映射和区域策略拦截
- 人工验证使用 Sandbox / 开发签名环境完成真实 Sign in with Apple

### Feature 53.8：App 端订阅交易上报与后端订阅状态同步

目标：

- StoreKit 购买成功后将交易上报后端校验
- App 端订阅状态以后端 `/v1/subscriptions/status` 为准
- 本地 StoreKit entitlement 只作为购买恢复入口和用户提示，不作为最终 AI 权限来源

实现方案：

- 扩展 `AIProSubscriptionService`：
  - 购买成功并本地 verified 后读取 `Transaction.jwsRepresentation`
  - 调用后端 `POST /v1/subscriptions/verify`
  - 恢复购买后遍历当前有效 entitlement，将最新交易上报后端
  - 交易监听收到更新时，同步上报后端
- 扩展 `AIProBackendClient`：
  - `verifySubscription(signedTransaction:)`
  - `fetchSubscriptionStatus()`
  - 将后端 `active`、`grace_period`、`expired`、`refunded` 等状态映射为 App 端可展示状态
- AI Pro 弹窗逻辑调整：
  - 未登录时先登录
  - 已登录但未订阅时展示订阅商品与购买 / 恢复入口
  - 购买成功后立即上报后端并刷新后端订阅状态
  - 后端确认 active / grace_period 后，才允许进入 AI 请求流程
- 后端返回 `subscription_required`、`verification_failed` 或网络失败时，保留本地购买结果但提示“等待服务端校验 / 请稍后重试”。

验收：

- 未登录时不会发起订阅上报
- 购买成功后会调用 `/v1/subscriptions/verify`
- 恢复购买会尝试上报当前有效交易
- 后端订阅状态 active / grace_period 时 App 端允许继续 AI 请求
- 后端订阅状态 inactive / expired / refunded 时 App 端不调用 AI 后端
- 单元测试覆盖订阅状态映射、购买后上报成功、上报失败、恢复购买和交易监听路径
- 人工验证使用 StoreKit Sandbox / 本地 StoreKit 配置完成购买、恢复和后端订阅状态刷新

### Feature 53.9：App 端 AI 点击走后端接口

目标：

- 普通截图和长截图的 AI 点击行为接入正式后端 AI Pro 链路
- 订阅用户点击 AI 后调用后端 `/v1/ai/analyze-screenshot` 或 `/v1/ai/analyze-text`
- 历史本地 API Key 链路继续仅保留为 Debug / 开发者能力，不作为正式商业路径

实现方案：

- 新增 App 端后端 AI 服务，例如 `AIProBackendAIService`：
  - `analyzeScreenshot(imageBase64:prompt:requestID:)`
  - `analyzeText(prompt:requestID:)`
  - 统一处理 `401`、`402`、`403`、`409`、`413`、`429`、`502`
- 普通截图：
  - AI 按钮先执行区域策略、登录状态、后端订阅状态检查
  - 校验通过后再展示现有 AI 模式菜单
  - 用户选择模式后，将截图编码为 base64，并调用 `/v1/ai/analyze-screenshot`
  - 返回结果复用现有 `AIAnalysisPreviewWindowService` 展示
- 长截图：
  - 与普通截图共用同一套 AI Pro flow
  - 长图需要遵守后端 `MAX_IMAGE_BYTES`
  - 超过大小时在 App 端提前提示，避免上传必失败图片
- 文本类模式：
  - 如果已有 OCR 文本或本地提取文本，可调用 `/v1/ai/analyze-text`
  - 如需要图片理解，则调用 `/v1/ai/analyze-screenshot`
- 请求安全：
  - 每次请求生成唯一 `request_id`
  - 不在 App 内保存 AI Provider API Key
  - 中国大陆 / unknown 不发起任何后端 AI 请求
  - 未登录、未订阅、超额、后端失败都有明确 UI 提示

验收：

- 中国大陆 / unknown 模式下点击 AI 不登录、不订阅、不请求后端
- 海外未登录点击 AI 先进入 Apple 登录
- 海外已登录未订阅点击 AI 进入订阅购买 / 恢复流程
- 海外已登录且后端订阅 active 时，普通截图 AI 能调用后端接口
- 长截图 AI 与普通截图使用同一套权限与错误处理逻辑
- 后端返回 `subscription_required`、`monthly_quota_exceeded`、`daily_quota_exceeded`、`image_too_large`、`ai_provider_failed` 时 App 展示可理解提示
- 成功结果能在现有 AI 分析预览窗口展示，并支持复制结果
- 单元测试覆盖 App 端状态机：未登录、未订阅、已订阅、区域禁止、额度超限、后端失败、成功返回

### Feature 53.10：隐私、审核与上架材料

目标：

- 更新海外 AI 功能所需隐私说明
- 更新 App Store 文案策略
- 增加首次使用 AI 上传提示

验收：

- 隐私政策说明 AI 上传边界
- 中国大陆 App Store 文案不宣传 AI
- 海外 AI 功能说明包含订阅、上传、第三方模型处理提示
- 首次使用 AI 前明确提示截图内容会上传至后端和第三方模型服务
- 说明登录、订阅、额度和截图处理的用户数据边界

---

## Sprint Scope

### Included

本 Sprint 包含：

- 明确区域化产品需求
- 明确 App 端区域策略技术方案
- 明确历史 AI 隐藏配置与商业 AI 路径边界
- 明确 StoreKit、Apple 登录、后端会话、订阅上报、AI 请求、额度、隐私的 Feature 拆分
- 更新当前项目文档入口
- 将后续执行范围纳入 Roadmap

### Out of Scope

本 Sprint 不直接实现：

- App Store Connect 商品配置（需手动在 Apple Developer Console 配置）
- 中国大陆 AI 服务

---

## System Design

### 实现思路

第一阶段先在 App 内建立本地可测试的区域策略和功能开关，避免商业 AI 能力直接散落在 UI、Settings 和业务编排中。

后续所有 AI 商业能力都通过统一入口判断：

```text
RegionPolicy
↓
FeatureFlags
↓
AIAvailabilityService
↓
UI Entry / Login / Subscription / Server API
```

### 涉及模块

后续实现预计涉及：

- `TYScreenShotTool/Shared/`
  - 区域策略、功能开关、AI 可用性模型
- `TYScreenShotTool/App/`
  - Settings、菜单栏、应用装配
- `TYScreenShotTool/Services/`
  - Apple 登录服务、后端 API 客户端、AI 分析服务、截图业务编排、订阅状态服务
- `TYScreenShotTool/Features/`
  - 普通截图工具栏、长截图控制面板、AI Pro 入口
- `TYScreenShotToolTests/`
  - 区域策略、功能开关、登录状态、订阅状态、AI Pro flow 和额度模型纯逻辑测试
- Serverless 后端仓库或目录
  - Cloudflare Workers、Supabase schema、API 合约

### 验证方式

- 优先通过单元测试验证区域策略、功能开关和状态组合
- 通过人工测试验证中国大陆模式无 AI 商业入口、无登录、无订阅
- 通过人工测试验证海外模式可进入 AI Pro 壳层
- 后续 StoreKit 与 AI 后端接入使用 Sandbox 和测试账号验证

---

## Validation Plan

### 文档验收

1. `docs/SPRINTS/Sprint-53.md` 明确 Sprint 目标、范围、需求、技术方案和 Feature 拆分
2. `docs/ROADMAP.md` 将 Sprint 53 标记为当前 Sprint
3. `PROJECT_CONTEXT.md` 同步当前 Sprint、AI 区域化边界和文档地图
4. 不创建 `PLAN.md`、`DESIGN.md`、`IMPLEMENTATION_PLAN.md`、`REVIEW.md`、`REPORT.md`、`TODO.md`

### 后续功能验收基线

1. 中国大陆模式下：
   - 不显示 AI 商业入口
   - 不显示登录入口
   - 不显示订阅入口
   - 不请求后端
   - 本地截图、OCR、本地翻译正常

2. 海外模式下：
   - 可看到 AI Pro 入口
   - 未登录先提示登录
   - 未订阅先提示订阅
   - 未订阅不调用 AI API
   - 已订阅后普通截图和长截图 AI 请求走后端接口

3. 后端模式下：
   - 后端最终校验地区、登录、订阅和额度
   - AI API Key 只在后端
   - 超额和未订阅请求不产生 AI 成本

---

## Result

本 Sprint 当前已完成区域化底座、AI Pro 壳层、StoreKit 本地订阅壳层、后端登录 / 订阅 / 通知 / AI 分析 MVP；App 端正式接入后端的登录、订阅上报和 AI 请求链路仍需继续补齐：

- Feature 53.1：App 区域策略底座 ✅
- Feature 53.2：AI 入口与历史隐藏配置隔离 ✅
- Feature 53.3：海外 AI Pro 壳层 ✅
- Feature 53.4：StoreKit 2 订阅接入 ✅
- Feature 53.5：Serverless 后端 MVP ✅（含 Apple Sign In 登录、订阅收据验证、通知 webhook、文字分析）
- Feature 53.6：AI 分析闭环与额度控制 ✅
- Feature 53.7：App 端 Apple 登录与后端会话接入（待开始）
- Feature 53.8：App 端订阅交易上报与后端订阅状态同步（待开始）
- Feature 53.9：App 端 AI 点击走后端接口（待开始）
- Feature 53.10：隐私、审核与上架材料（待开始）

后端共实现 8 个 API 端点，40 个单元测试全部通过。

完成标准：

- 当前 Sprint 文档完成
- Roadmap 与 Project Context 对齐
- 后续 Feature 切分清晰
- 下一步可以进入 Feature 53.7 的 App 端 Apple 登录与后端会话接入
