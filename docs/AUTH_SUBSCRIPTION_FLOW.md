# Sign In with Apple & 订阅功能流程图

## 目录

- [App 启动流程](#app-启动流程)
- [Sign In with Apple 登录流程](#sign-in-with-apple-登录流程)
- [用户登出流程](#用户登出流程)
- [订阅购买流程](#订阅购买流程)
- [订阅恢复流程](#订阅恢复流程)
- [订阅状态查询流程](#订阅状态查询流程)
- [AI Pro 使用流程](#ai-pro-使用流程)
- [区域策略检查流程](#区域策略检查流程)
- [核心组件说明](#核心组件说明)
- [关键代码引用](#关键代码引用)

---

## App 启动流程

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                      前端 (macOS)                                                   │
├─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                                     │
│  AppDelegate.applicationDidFinishLaunching()                                                                       │
│       │                                                                                                            │
│       ▼                                                                                                            │
│  AIProSessionManager.shared.restoreSession()                                                                        │
│       │                                                                                                            │
│       │  1. readFromKeychain(key: tokenKey) → 从 Keychain 读取 Token                                               │
│       │  2. userDefaults.string(forKey: userIDKey) → 从 UserDefaults 读取用户 ID                                    │
│       │  3. 验证 userID 是否为有效 UUID                                                                             │
│       │                                                                                                            │
│       │  ├─ 验证通过 → currentToken / currentUserID 设置成功                                                       │
│       │  └─ 验证失败 → 调用 signOut() 清除残留状态                                                                  │
│       │                                                                                                            │
│       ▼                                                                                                            │
│  AIProSubscriptionService.shared.startTransactionListener()                                                        │
│       │                                                                                                            │
│       │  Task {                                                                                                    │
│       │    for await result in Transaction.updates {                                                               │
│       │      if case .verified(let transaction) = result {                                                         │
│       │        await reportVerificationToBackend(result) → 自动上报新交易                                           │
│       │        await transaction.finish()                                                                          │
│       │      }                                                                                                     │
│       │      await refreshStatus() → 刷新订阅状态                                                                  │
│       │    }                                                                                                       │
│       │  }                                                                                                         │
│       │                                                                                                            │
│       ▼                                                                                                            │
│  AIProSubscriptionStatus.cachedStatus() → 从 UserDefaults 读取缓存的订阅状态                                         │
│       │                                                                                                            │
│       └─ 缓存存在 → status = 缓存状态                                                                               │
│       └─ 缓存不存在 → status = .notLoaded                                                                          │
│                                                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Sign In with Apple 登录流程

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                      前端 (macOS)                                                   │
├─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                                     │
│  用户点击登录按钮                                                                                                    │
│       │                                                                                                            │
│       ▼                                                                                                            │
│  SettingsViewController.handleLoginAction()                                                                        │
│       │                                                                                                            │
│       ▼                                                                                                            │
│  AIProAuthService.signIn()                                                                                         │
│       │                                                                                                            │
│       │  创建 ASAuthorizationAppleIDProvider 请求                                                                   │
│       │  request.requestedScopes = [.email]                                                                       │
│       │                                                                                                            │
│       ▼                                                                                                            │
│  ASAuthorizationController.performRequests()                                                                      │
│       │                                                                                                            │
│       │  ──────────── Apple ID 授权页面 ────────────                                                               │
│       │                                                                                                            │
│       ▼ (用户授权成功)                                                                                              │
│  authorizationController(didCompleteWithAuthorization:)                                                           │
│       │                                                                                                            │
│       │  credential.identityToken → String                                                                        │
│       │  credential.user (Apple 用户 ID)                                                                           │
│       │                                                                                                            │
│       ▼                                                                                                            │
│  AIProBackendClient.authApple(identityToken:)                                                                     │
│       │                                                                                                            │
│       │  POST /v1/auth/apple                                                                                      │
│       │  Body: {                                                                                                  │
│       │    "identity_token": "...",                                                                               │
│       │    "storefront": "USA"  (新增)                                                                             │
│       │  }                                                                                                        │
│       │                                                                                                            │
│       └───────────────────────────────────────────────────────────────────────────────────────────────────────────┘
│                                                                                                                     │
│                                                      HTTP 请求                                                    │
│                                                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
                                                                                             │
                                                                                             ▼
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                     后端 (Cloudflare Worker)                                       │
├─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                                     │
│  handleAuthApple()                                                                                                 │
│       │                                                                                                            │
│       │  解析请求体 → identity_token, storefront                                                                  │
│       │                                                                                                            │
│       ▼                                                                                                            │
│  verifyAppleJWT(identityToken, bundleId)                                                                          │
│       │                                                                                                            │
│       │  1. 从 Apple 获取公钥 https://appleid.apple.com/auth/keys                                                 │
│       │  2. 验证 JWT 签名 (RS256)                                                                                  │
│       │  3. 验证 claims:                                                                                           │
│       │     - iss === "https://appleid.apple.com"                                                                 │
│       │     - aud === bundleId                                                                                     │
│       │     - sub (Apple 用户 ID) 存在                                                                             │
│       │     - exp 未过期                                                                                           │
│       │                                                                                                            │
│       ▼ (验证成功)                                                                                                 │
│  findOrCreateUser(claims.sub, claims.email, storefront)                                                           │
│       │                                                                                                            │
│       │  查询 users 表: apple_user_id = claims.sub                                                                │
│       │     ├─ 已存在 → 更新 storefront (如果变更)                                                                 │
│       │     └─ 不存在 → 创建新用户                                                                                 │
│       │                                                                                                            │
│       ▼                                                                                                            │
│  createSession(userId)                                                                                            │
│       │                                                                                                            │
│       │  生成 32 字节随机 Token → SHA-256 哈希                                                                     │
│       │  存入 app_sessions 表 (有效期 7 天)                                                                        │
│       │                                                                                                            │
│       ▼                                                                                                            │
│  返回响应: {                                                                                                       │
│    "token": "abc123...",  (Bearer Token)                                                                          │
│    "user_id": "uuid-xxx"                                                                                          │
│  }                                                                                                                 │
│                                                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
                                                                                             │
                                                                                             ▼
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                      前端 (macOS)                                                   │
├─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                                     │
│  AIProAuthService.complete(response:)                                                                             │
│       │                                                                                                            │
│       ▼                                                                                                            │
│  AIProSessionManager.saveSession(token:, userID:)                                                                 │
│       │                                                                                                            │
│       │  - currentToken = token                                                                                   │
│       │  - currentUserID = userID                                                                                 │
│       │  - 写入 Keychain (token)                                                                                   │
│       │  - 写入 UserDefaults (userID)                                                                             │
│       │                                                                                                            │
│       ▼                                                                                                            │
│  返回 (token, userID)                                                                                              │
│       │                                                                                                            │
│       ▼                                                                                                            │
│  signInAndRefreshStatus()                                                                                         │
│       │                                                                                                            │
│       │  AIProSubscriptionService.refreshStatus()                                                                  │
│       │     └─ fetchSubscriptionStatus() → 查询后端订阅状态                                                        │
│       │                                                                                                            │
│       ▼                                                                                                            │
│  reloadLoginStatus() → 更新 UI                                                                                     │
                                                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 用户登出流程

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                      前端 (macOS)                                                   │
├─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                                     │
│  用户点击登出按钮                                                                                                    │
│       │                                                                                                            │
│       ▼                                                                                                            │
│  SettingsViewController.handleLoginAction()                                                                        │
│       │                                                                                                            │
│       │  AIProSessionManager.shared.signOut()                                                                      │
│       │       │                                                                                                    │
│       │       │  - currentToken = nil                                                                              │
│       │       │  - currentUserID = nil                                                                             │
│       │       │  - deleteFromKeychain(key: tokenKey) → 删除 Keychain 中的 Token                                    │
│       │       │  - userDefaults.removeObject(forKey: userIDKey) → 删除 UserDefaults 中的用户 ID                    │
│       │       │                                                                                                    │
│       │       ▼                                                                                                    │
│       │  重置订阅状态:                                                                                              │
│       │    AIProSubscriptionService.shared.status = .notLoaded                                                     │
│       │    清除缓存: status.saveCachedStatus() → UserDefaults                                                      │
│       │                                                                                                            │
│       ▼                                                                                                            │
│  reloadLoginStatus() → 更新 UI（显示登录按钮）                                                                      │
│                                                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

> **说明**: 登出仅在前端本地清除状态，不调用后端 API。后端 session 会在 7 天后自动过期。

---

## 订阅购买流程

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                      前端 (macOS)                                                   │
├─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                                     │
│  用户点击订阅按钮                                                                                                    │
│       │                                                                                                            │
│       ▼                                                                                                            │
│  AIProSubscriptionService.purchaseMonthly()                                                                        │
│       │                                                                                                            │
│       │  1. 加载产品信息: Product.products(for: [productID])                                                      │
│       │  2. 获取 appAccountToken = currentUserID (关联用户)                                                        │
│       │                                                                                                            │
│       ▼                                                                                                            │
│  Product.purchase(options: [.appAccountToken(appAccountToken)])                                                   │
│       │                                                                                                            │
│       │  ──────────── App Store 购买流程 ────────────                                                               │
│       │                                                                                                            │
│       ▼ (购买成功)                                                                                                  │
│  .success(.verified(transaction))                                                                                  │
│       │                                                                                                            │
│       │  transaction.jwsRepresentation → signedTransaction                                                         │
│       │                                                                                                            │
│       ▼                                                                                                            │
│  reportVerificationToBackend(verification)                                                                        │
│       │                                                                                                            │
│       │  POST /v1/subscriptions/verify                                                                             │
│       │  Body: { "signed_transaction": "eyJhbGciOiJFUzI1Ni..." }                                                 │
│       │  Header: Authorization: Bearer xxx                                                                         │
│       │                                                                                                            │
│       └───────────────────────────────────────────────────────────────────────────────────────────────────────────┘
│                                                                                                                     │
│                                                      HTTP 请求                                                    │
│                                                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
                                                                                             │
                                                                                             ▼
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                     后端 (Cloudflare Worker)                                       │
├─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                                     │
│  handleVerifySubscription()                                                                                        │
│       │                                                                                                            │
│       │  1. 验证 Authorization Header → 获取用户 ID                                                                │
│       │  2. 解析请求体 → signed_transaction                                                                        │
│       │                                                                                                            │
│       ▼                                                                                                            │
│  verifyStoreKitTransactionJWT(signedTransaction, bundleId)                                                        │
│       │                                                                                                            │
│       │  使用 @apple/app-store-server-library 验证 JWT                                                            │
│       │  支持环境: Xcode / LocalTesting / Sandbox / Production                                                     │
│       │                                                                                                            │
│       ▼ (验证成功)                                                                                                 │
│  提取交易信息:                                                                                                      │
│    - transactionId                                                                                                 │
│    - originalTransactionId                                                                                         │
│    - productId                                                                                                     │
│    - environment                                                                                                   │
│    - expiresDate                                                                                                   │
│    - appAccountToken                                                                                               │
│       │                                                                                                            │
│       │  校验 productId === AI_PRO_MONTHLY_PRODUCT_ID                                                              │
│       │                                                                                                            │
│       ▼                                                                                                            │
│  判断订阅状态:                                                                                                      │
│    expiresDate > now → "active"                                                                                    │
│    expiresDate <= now → "expired"                                                                                  │
│       │                                                                                                            │
│       ▼                                                                                                            │
│  createOrUpdateSubscription(userId, transaction)                                                                  │
│       │                                                                                                            │
│       │  查询 subscriptions 表: original_transaction_id = xxx                                                      │
│       │     ├─ 已存在 → UPDATE (更新 latest_transaction_id, expires_at, status)                                    │
│       │     └─ 不存在 → INSERT (创建新订阅记录)                                                                    │
│       │                                                                                                            │
│       ▼                                                                                                            │
│  返回响应: {                                                                                                       │
│    "status": "active",                                                                                             │
│    "product_id": "tshot.pro.monthly",                                                                              │
│    "expires_at": "2026-07-29T04:56:52Z",                                                                          │
│    "environment": "Xcode"                                                                                          │
│  }                                                                                                                 │
│                                                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
                                                                                             │
                                                                                             ▼
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                      前端 (macOS)                                                   │
├─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                                     │
│  reportVerificationToBackend() 返回 true/false                                                                     │
│       │                                                                                                            │
│       ▼                                                                                                            │
│  更新订阅状态:                                                                                                      │
│    status = AIProSubscriptionStatus.subscribed(product)                                                           │
│    status.saveCachedStatus() → 缓存到 UserDefaults                                                                 │
│       │                                                                                                            │
│       ▼                                                                                                            │
│  await transaction.finish() → 完成交易                                                                            │
│                                                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 订阅恢复流程

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                      前端 (macOS)                                                   │
├─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                                     │
│  触发时机:                                                                                                          │
│    1. 登录成功后自动调用                                                                                            │
│    2. 用户手动点击"恢复订阅"按钮                                                                                     │
│       │                                                                                                            │
│       ▼                                                                                                            │
│  AIProSubscriptionService.restorePurchases()                                                                       │
│       │                                                                                                            │
│       │  try await AppStore.sync() → 同步 App Store 交易                                                           │
│       │                                                                                                            │
│       ▼                                                                                                            │
│  for await result in Transaction.currentEntitlements                                                               │
│       │                                                                                                            │
│       │  遍历当前有效的订阅交易                                                                                     │
│       │  productID === AIProSubscriptionProductID.monthly                                                          │
│       │                                                                                                            │
│       ▼                                                                                                            │
│  reportVerificationToBackend(result)                                                                               │
│       │                                                                                                            │
│       │  ↓ 同订阅购买流程的后端验证 ↓                                                                               │
│       │                                                                                                            │
│       ▼ (验证成功)                                                                                                 │
│  更新订阅状态 → transaction.finish()                                                                               │
│       │                                                                                                            │
│       ▼                                                                                                            │
│  refreshStatus() → 从后端刷新最新状态                                                                              │
│       │                                                                                                            │
│       ▼                                                                                                            │
│  返回订阅状态                                                                                                       │
│                                                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 订阅状态查询流程

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                      前端 (macOS)                                                   │
├─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                                     │
│  AIProSubscriptionService.refreshStatus()                                                                          │
│       │                                                                                                            │
│       │  1. 加载产品信息: Product.products()                                                                        │
│       │  2. 获取后端订阅状态                                                                                        │
│       │                                                                                                            │
│       ▼                                                                                                            │
│  AIProBackendClient.fetchSubscriptionStatus()                                                                      │
│       │                                                                                                            │
│       │  GET /v1/subscriptions/status                                                                             │
│       │  Header: Authorization: Bearer xxx                                                                         │
│       │                                                                                                            │
│       └───────────────────────────────────────────────────────────────────────────────────────────────────────────┘
│                                                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
                                                                                             │
                                                                                             ▼
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                     后端 (Cloudflare Worker)                                       │
├─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                                     │
│  handleGetSubscriptionStatus()                                                                                     │
│       │                                                                                                            │
│       │  1. 验证 Authorization Header → 获取用户 ID                                                                │
│       │  2. 验证区域: validateRegion(user.storefront)                                                              │
│       │     ├─ storefront === "CHN" → 403 region_unavailable                                                      │
│       │     └─ storefront 为空 → 403 region_unavailable                                                           │
│       │                                                                                                            │
│       ▼                                                                                                            │
│  查询 subscriptions 表:                                                                                            │
│    SELECT * FROM subscriptions WHERE user_id = xxx ORDER BY expires_at DESC LIMIT 1                                │
│       │                                                                                                            │
│       │  判断状态:                                                                                                  │
│       │    - expires_at > now → "active"                                                                           │
│       │    - expires_at <= now → "expired"                                                                         │
│       │    - 无记录 → "inactive"                                                                                   │
│       │                                                                                                            │
│       ▼                                                                                                            │
│  返回响应: {                                                                                                       │
│    "user_id": "uuid-xxx",                                                                                          │
│    "status": "active",                                                                                             │
│    "product_id": "tshot.pro.monthly",                                                                              │
│    "expires_at": "2026-07-29T04:56:52Z"                                                                           │
│  }                                                                                                                 │
│                                                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
                                                                                             │
                                                                                             ▼
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                      前端 (macOS)                                                   │
├─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                                     │
│  根据后端响应更新状态:                                                                                               │
│    AIProSubscriptionStatus.statusAfterBackendRefresh()                                                             │
│       │                                                                                                            │
│       │  - active/subscribed → 显示订阅状态                                                                        │
│       │  - expired → 显示"已过期"                                                                                   │
│       │  - inactive → 显示"未订阅"                                                                                  │
│       │  - regionUnavailable → 显示"当前区域不可用"                                                                │
│       │                                                                                                            │
│       ▼                                                                                                            │
│  status.saveCachedStatus() → 缓存到 UserDefaults                                                                   │
│                                                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## AI Pro 使用流程

```
用户点击 AI 按钮
       │
       ▼
CaptureOverlayView.requestAI()
       │
       │  presentAIMenu(relativeTo: aiButton) → 弹出功能菜单
       │
       ▼ (选择功能，如"开发报错分析")
CaptureSessionService.performAIAnalysis()
       │
       │  1. 截取图片
       │  2. 调用后端 AI 分析
       │
       ▼
AIProBackendClient.analyzeScreenshot()
       │
       │  POST /v1/ai/analyze-screenshot
       │  Body: {
       │    "request_id": "uuid",
       │    "image_base64": "...",
       │    "prompt": "..."
       │  }
       │  Header: Authorization: Bearer xxx
       │
       └───────────────────────────────────────────────────────────────────────────────────────────────────────────┘
                                                       │
                                                       ▼
后端验证:
  1. Token 验证 → 用户身份
  2. 区域验证 → storefront 非 CHN
  3. 订阅状态验证 → active/grace_period
  4. 用量验证 → monthly_used_count < monthly_limit_count
                                                       │
                                                       ▼
调用 OpenAI API → 返回分析结果
                                                       │
                                                       ▼
前端显示 AI 分析结果
```

---

## 区域策略检查流程

### 前端区域策略检查

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                      前端 (macOS)                                                   │
├─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                                     │
│  AppRegionPolicyProvider.currentPolicy()                                                                           │
│       │                                                                                                            │
│       │  1. 获取系统区域设置: Locale.current.regionCode                                                             │
│       │  2. 获取 App Store 区域: SKPaymentQueue.default().storefront?.countryCode                                  │
│       │                                                                                                            │
│       │  判断逻辑:                                                                                                  │
│       │    - 区域为 CN (中国大陆) → .china                                                                        │
│       │    - 区域未知 → .unknown                                                                                    │
│       │    - 其他区域 → .overseas                                                                                   │
│       │                                                                                                            │
│       ▼                                                                                                            │
│  根据策略决定行为:                                                                                                   │
│    - .china / .unknown:                                                                                            │
│        - 不显示 AI 按钮                                                                                             │
│        - 不启动 StoreKit 交易监听                                                                                   │
│        - 不加载订阅商品                                                                                             │
│        - 不触发任何后端请求                                                                                         │
│    - .overseas:                                                                                                    │
│        - 显示 AI 按钮                                                                                               │
│        - 启动 StoreKit 交易监听                                                                                     │
│        - 加载订阅商品                                                                                               │
│        - 允许登录和订阅                                                                                             │
│                                                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

### 后端区域策略检查

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                     后端 (Cloudflare Worker)                                       │
├─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                                     │
│  validateRegion(user.storefront)                                                                                   │
│       │                                                                                                            │
│       │  检查条件:                                                                                                  │
│       │    - storefront === "CHN" → 区域不可用                                                                      │
│       │    - storefront 为空 → 区域不可用                                                                           │
│       │    - storefront 非 CHN 且非空 → 区域可用                                                                    │
│       │                                                                                                            │
│       ▼                                                                                                            │
│  区域验证失败 → 返回 403 regionUnavailable                                                                          │
│       │                                                                                                            │
│       ▼ (区域验证成功)                                                                                              │
│  继续后续业务逻辑 (订阅状态查询 / AI 分析等)                                                                          │
│                                                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

> **说明**: 区域策略采用前端+后端双重校验机制：
> - 前端：基于设备区域设置决定是否显示 AI 入口和订阅功能
> - 后端：基于用户登录时记录的 storefront 字段进行最终权限校验
> - 中国大陆用户（CHN）无法使用 AI Pro 功能

---

## 核心组件说明

### 前端组件

| 组件 | 文件路径 | 职责 |
|------|----------|------|
| **AIProAuthService** | `Services/AIProAuthService.swift` | 发起 Apple 登录、获取 identity token、调用后端认证 |
| **AIProSubscriptionService** | `Services/AIProSubscriptionService.swift` | 订阅购买、恢复、状态查询、交易监听 |
| **AIProBackendClient** | `Services/AIProBackendClient.swift` | 后端 API 统一网络客户端（认证、订阅、AI、用量） |
| **AIProSessionManager** | `Services/AIProSessionManager.swift` | 管理登录会话（Bearer Token、用户 ID），使用 Keychain 存储 |
| **SettingsViewController** | `App/SettingsViewController.swift` | 设置界面，处理登录/订阅按钮点击 |
| **AIProPromptPresenter** | `Services/AIProPromptPresenter.swift` | AI Pro 访问状态检查（登录/订阅/地区） |

### 后端组件

| 组件 | 文件路径 | 职责 |
|------|----------|------|
| **app.ts** | `backend/worker/src/app.ts` | 路由处理，认证/订阅/AI API 入口 |
| **appleAuth.ts** | `backend/worker/src/appleAuth.ts` | Apple JWT 验证（Sign In、StoreKit） |
| **supabaseRepository.ts** | `backend/worker/src/supabaseRepository.ts` | Supabase 数据库操作（用户、会话、订阅、用量） |
| **openAIProvider.ts** | `backend/worker/src/openAIProvider.ts` | OpenAI API 调用封装 |

### 数据库表

| 表名 | 用途 | 关键字段 |
|------|------|----------|
| **users** | 用户档案 | id, apple_user_id, email, storefront, country_code |
| **app_sessions** | 登录会话 | user_id, token_hash, expires_at |
| **subscriptions** | 订阅记录 | user_id, product_id, original_transaction_id, latest_transaction_id, status, expires_at, environment |
| **usage_records** | 用量记录 | user_id, request_type, used_count, created_at |

---

## API 接口列表

### 认证接口

| 接口 | 方法 | 需要认证 | 说明 |
|------|------|----------|------|
| `/v1/auth/apple` | POST | 否 | Apple Sign In |

### 订阅接口

| 接口 | 方法 | 需要认证 | 说明 |
|------|------|----------|------|
| `/v1/subscriptions/verify` | POST | 是 | 验证 StoreKit 交易 |
| `/v1/subscriptions/status` | GET | 是 | 查询订阅状态 |

### AI 接口

| 接口 | 方法 | 需要认证 | 说明 |
|------|------|----------|------|
| `/v1/ai/analyze-screenshot` | POST | 是 | 截图 AI 分析 |
| `/v1/ai/analyze-text` | POST | 是 | 文字 AI 分析 |

### 用量接口

| 接口 | 方法 | 需要认证 | 说明 |
|------|------|----------|------|
| `/v1/usage/current` | GET | 是 | 查询当前用量 |

---

## 错误码说明

| HTTP 状态码 | AIProBackendError | 说明 |
|-------------|-------------------|------|
| 401 | authRequired | 未登录或 token 过期 |
| 402 | subscriptionRequired | 需要有效订阅 |
| 403 | regionUnavailable | 当前区域不可用 |
| 409 | duplicateRequest | 重复请求 |
| 413 | imageTooLarge | 图片太大 |
| 422 | providerInputUnsupported | AI Provider 不支持 |
| 429 | quotaExceeded | 额度用尽 |
| 502 | providerFailed | AI Provider 调用失败 |

---

## 数据流总结

```
用户登录:
  Apple → identityToken → 后端 → verifyAppleJWT → findOrCreateUser → createSession → token → 前端 → Keychain

订阅购买:
  StoreKit → signedTransaction → 后端 → verifyStoreKitTransactionJWT → createOrUpdateSubscription → status → 前端

订阅恢复:
  AppStore.sync() → Transaction.currentEntitlements → 后端验证 → 更新状态

AI 使用:
  图片 → 后端 → 验证(登录/区域/订阅/用量) → OpenAI → 分析结果 → 前端
```

---

## 关键代码引用

### 登录流程核心代码

**AIProAuthService.signIn()** (`Services/AIProAuthService.swift:37`)

```swift
func signIn() async throws -> (token: String, userID: String) {
    let request = ASAuthorizationAppleIDProvider().createRequest()
    request.requestedScopes = [.email]
    let controller = ASAuthorizationController(authorizationRequests: [request])
    controller.delegate = self
    controller.presentationContextProvider = self
    controller.performRequests()
    // ... 等待 delegate 返回，调用后端 authApple
}
```

**AIProAuthService.complete()** (`Services/AIProAuthService.swift:107`)

```swift
private func complete(response: AuthAppleResponse) {
    sessionManager.saveSession(token: response.token, userID: response.user_id)
    continuation?.resume(returning: response)
}
```

**后端 handleAuthApple()** (`backend/worker/src/app.ts:473`)

```typescript
async function handleAuthApple(context: RequestContext): Promise<Response> {
    const claims = await verifyAppleJWT(identityToken, context.env.APPLE_BUNDLE_ID);
    const user = await context.repository.findOrCreateUser(claims.sub, claims.email, storefront);
    const token = await context.repository.createSession(user.id);
    return json({ token, user_id: user.id });
}
```

### 订阅购买核心代码

**AIProSubscriptionService.purchaseMonthly()** (`Services/AIProSubscriptionService.swift:96`)

```swift
func purchaseMonthly() async -> AIProSubscriptionStatus {
    let result = try await product.purchase(options: [.appAccountToken(appAccountToken)])
    switch result {
    case .success(let verification):
        guard case .verified(let transaction) = verification else { ... }
        let backendConfirmed = await reportVerificationToBackend(verification)
        status = AIProSubscriptionStatus.statusAfterVerifiedPurchase(
            product: makeProductViewModel(from: product),
            backendConfirmed: backendConfirmed
        )
    // ...
    }
}
```

**AIProSubscriptionService.reportVerificationToBackend()** (`Services/AIProSubscriptionService.swift:231`)

```swift
func reportVerificationToBackend(_ verification: VerificationResult<Transaction>) async -> Bool {
    let jws = verification.jwsRepresentation
    let response = try await backendClient.verifySubscription(signedTransaction: jws)
    return response.status == "active" || response.status == "grace_period"
}
```

**后端 handleVerifySubscription()** (`backend/worker/src/app.ts:517`)

```typescript
async function handleVerifySubscription(context: AuthenticatedContext): Promise<Response> {
    const transaction = await verifyStoreKitTransactionJWT(signedTransaction, bundleId, config);
    const status = transaction.expiresDate && transaction.expiresDate > now ? "active" : "expired";
    await context.repository.createOrUpdateSubscription(context.user.id, {
        originalTransactionId: transaction.originalTransactionId,
        latestTransactionId: transaction.transactionId,
        productId: transaction.productId,
        environment: transaction.environment,
        expiresAt: transaction.expiresDate ? new Date(transaction.expiresDate).toISOString() : null
    });
}
```

### 订阅恢复核心代码

**AIProSubscriptionService.restorePurchases()** (`Services/AIProSubscriptionService.swift:147`)

```swift
func restorePurchases() async -> AIProSubscriptionStatus {
    try await AppStore.sync()
    for await result in Transaction.currentEntitlements {
        guard case .verified(let transaction) = result,
              transaction.productID == AIProSubscriptionProductID.monthly else { continue }
        if await reportVerificationToBackend(result) {
            status = AIProSubscriptionStatus.subscribed(product)
            await transaction.finish()
        }
    }
    return await refreshStatus()
}
```

### 会话管理核心代码

**AIProSessionManager.saveSession()** (`Services/AIProSessionManager.swift:53`)

```swift
func saveSession(token: String, userID: String) {
    currentToken = token
    currentUserID = userID
    writeToKeychain(key: tokenKey, value: token)      // Token 存入 Keychain
    userDefaults.set(userID, forKey: userIDKey)       // 用户 ID 存入 UserDefaults
}
```

**AIProSessionManager.signOut()** (`Services/AIProSessionManager.swift:66`)

```swift
func signOut() {
    currentToken = nil
    currentUserID = nil
    deleteFromKeychain(key: tokenKey)                 // 删除 Keychain 中的 Token
    userDefaults.removeObject(forKey: userIDKey)      // 删除 UserDefaults 中的用户 ID
}
```

### 设置界面集成

**SettingsViewController.handleLoginAction()** (`App/SettingsViewController.swift`)

```swift
@objc func handleLoginAction() {
    if AIProSessionManager.shared.isSignedIn {
        AIProSessionManager.shared.signOut()
    } else {
        Task {
            _ = try await AIProAuthService.shared.signIn()
            await AIProSubscriptionService.shared.restorePurchases()
        }
    }
    reloadLoginStatus()
}
```