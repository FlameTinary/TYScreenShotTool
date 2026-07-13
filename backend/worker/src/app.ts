import { verifyAppleJWT, verifyAppStoreNotificationJWT, verifyStoreKitTransactionJWT, type AppStoreNotificationPayload, type AppStoreSignedDataVerificationConfig, type StoreKitTransactionPayload } from "./appleAuth";

const AI_PRO_MONTHLY_PRODUCT_ID = "tshot.pro.monthly";

/**
 * 用户订阅状态枚举
 * @enum {string}
 * @description active - 活跃订阅
 * @description inactive - 非活跃订阅
 * @description expired - 过期订阅
 * @description refunded - 已退款订阅
 * @description grace_period - 试用期订阅
 */
export type SubscriptionStatus = "active" | "inactive" | "expired" | "refunded" | "grace_period";

/**
 * 用户档案接口，描述已认证用户的基本信息
 */
export interface UserProfile {
  /** 用户唯一标识符 */
  id: string;
  /** App Store 地区代码（如 "USA", "CHN"），null 表示未知 */
  storefront: string | null;
  /** 国家代码（如 "US", "CN"），null 表示未知 */
  countryCode: string | null;
  /** 当前订阅状态 */
  subscriptionStatus: SubscriptionStatus;
  /** 当月已使用的 AI 请求次数 */
  monthlyUsedCount: number;
  /** 当日已使用的 AI 请求次数 */
  dailyUsedCount: number;
}

/**
 * 用量快照接口，描述用户当前的用量情况
 */
export interface UsageSnapshot {
  /** 用户唯一标识符 */
  userId: string;
  /** 当月已使用次数 */
  monthlyUsedCount: number;
  /** 当月配额上限 */
  monthlyLimitCount: number;
  /** 当日已使用次数 */
  dailyUsedCount: number;
  /** 当日配额上限 */
  dailyLimitCount: number;
}

/**
 * 用量记录状态枚举
 * @enum {string}
 * @description accepted - 请求已接受，等待处理
 * @description blocked - 请求已被阻止，不允许处理
 * @description succeeded - 请求处理成功
 * @description failed - 请求处理失败
 */
export type UsageRecordStatus = "accepted" | "blocked" | "succeeded" | "failed";

/**
 * 用量记录快照接口，描述单次请求的记录状态
 */
export interface UsageRecordSnapshot {
  /** 请求唯一标识符 */
  requestId: string;
  /** 请求状态 */
  status: UsageRecordStatus;
}

/**
 * 用量记录输入接口，用于创建新的用量记录
 */
export interface UsageRecordInput {
  /** 用户唯一标识符 */
  userId: string;
  /** 请求唯一标识符 */
  requestId: string;
  /** 请求类型：analyze_screenshot（图片分析）/ analyze_text（文字分析） */
  requestType: "analyze_screenshot" | "analyze_text";
  /** 使用的 AI 模型名称 */
  model: string | null;
  /** 图片字节大小 */
  imageBytes: number;
  /** 图片数量 */
  imageCount: number;
  /** 输入 Token 数量 */
  inputTokenCount: number;
  /** 输出 Token 数量 */
  outputTokenCount: number;
  /** 预估费用 */
  estimatedCost: number;
  /** 是否可计费 */
  billable: boolean;
  /** 请求状态 */
  status: UsageRecordStatus;
  /** AI 返回的文本结果（可选） */
  outputText?: string;
}

/**
 * 订阅快照接口，描述用户订阅的最新状态
 */
export interface SubscriptionSnapshot {
  /** 用户唯一标识符 */
  userId: string;
  /** 订阅状态 */
  status: SubscriptionStatus;
  /** 产品 ID（如 "tshot.pro.monthly"），null 表示无订阅 */
  productId: string | null;
  /** 订阅过期时间（ISO 格式），可选 */
  expiresAt?: string | null;
}

/**
 * 订阅交易输入接口，用于 createOrUpdateSubscription
 */
export interface SubscriptionTransactionInput {
  /** 原始交易 ID */
  originalTransactionId: string;
  /** 最新交易 ID */
  latestTransactionId: string;
  /** 产品 ID */
  productId: string;
  /** 交易环境 */
  environment: string;
  /** 订阅到期时间（ISO 格式） */
  expiresAt?: string | null;
  /** App Store 通知映射后的订阅状态；购买/恢复接口不传时由 expiresAt 推导 */
  status?: SubscriptionStatus;
}

/**
 * 后端数据访问层接口，定义数据持久化操作
 */
export interface BackendRepository {
  /**
   * 通过 Bearer Token 查找用户
   * @param token 用户认证令牌
   * @returns 用户档案，未找到时返回 null
   */
  findUserByBearerToken(token: string): Promise<UserProfile | null>;
  /**
   * 通过请求 ID 查找用量记录
   * @param userId 用户唯一标识符
   * @param requestId 请求唯一标识符
   * @returns 用量记录快照，未找到时返回 null
   */
  findUsageRecordByRequestId(userId: string, requestId: string): Promise<UsageRecordSnapshot | null>;
  /**
   * 获取用户当前用量
   * @param userId 用户唯一标识符
   * @returns 用量快照
   */
  getUsage(userId: string): Promise<UsageSnapshot>;
  /**
   * 获取用户订阅状态
   * @param userId 用户唯一标识符
   * @returns 订阅快照
   */
  getSubscriptionStatus(userId: string): Promise<SubscriptionSnapshot>;
  /**
   * 记录用量
   * @param record 用量记录输入
   */
  recordUsage(record: UsageRecordInput): Promise<void>;
  /**
   * 增加月度配额消耗
   * @param userId 用户唯一标识符
   * @param requestCount 请求次数增量
   * @param tokenCount Token 数量增量
   * @param cost 预估费用增量
   */
  incrementMonthlyQuota(userId: string, requestCount: number, tokenCount: number, cost: number): Promise<void>;
  /**
   * 按 Apple User ID 查找或创建用户
   * @param appleUserId Apple 用户唯一标识符
   * @param email 用户邮箱（可选）
   * @returns 用户档案
   */
  findOrCreateUser(appleUserId: string, email?: string, storefront?: string): Promise<UserProfile>;
  /**
   * 创建用户会话并返回 Bearer Token
   * @param userId 用户唯一标识符
   * @returns Bearer Token 字符串
   */
  createSession(userId: string): Promise<string>;
  /**
   * 创建或更新用户订阅记录
   * 按 originalTransactionId 查询，已存在则更新，否则创建新记录
   * @param userId 用户唯一标识符
   * @param transaction 交易信息
   */
  createOrUpdateSubscription(userId: string, transaction: SubscriptionTransactionInput): Promise<void>;
}

/**
 * 后端环境变量接口，定义运行时配置
 */
export interface BackendEnv {
  /** 允许访问的地区列表，逗号分隔 */
  ALLOWED_STOREFRONTS: string;
  /** 默认月度请求上限 */
  MONTHLY_REQUEST_LIMIT: string;
  /** 默认每日请求上限 */
  DAILY_REQUEST_LIMIT: string;
  /** 最大图片字节大小 */
  MAX_IMAGE_BYTES: string;
  /** AI 模型名称 */
  AI_MODEL: string;
  /** 最大输出 Token 数 */
  AI_MAX_OUTPUT_TOKENS: string;
  /** Apple 应用的 Bundle Identifier，用于验证 Apple JWT */
  APPLE_BUNDLE_ID: string;
  /** Apple Root CA PEM，用于验证 StoreKit / App Store Server Notification JWS 的 x5c 证书链 */
  APPLE_ROOT_CERTIFICATES_PEM?: string;
  /** App Store Connect 中的 Apple App ID，生产环境 JWS 校验需要 */
  APPLE_APP_ID?: string;
  /** 是否允许 Xcode / LocalTesting StoreKit 交易，仅限本地开发或测试环境开启 */
  ALLOW_LOCAL_STOREKIT_TRANSACTIONS?: string;
}

/**
 * AI 提供商请求接口
 */
export interface AIProviderRequest {
  /** 请求唯一标识符 */
  requestId: string;
  /** 用户唯一标识符 */
  userId: string;
  /** 图片的 Base64 编码字符串 */
  imageBase64: string;
  /** 提示词 */
  prompt: string;
  /** AI 模型名称 */
  model: string;
  /** 最大输出 Token 数 */
  maxOutputTokens: number;
}

/**
 * AI 提供商文字分析请求接口
 */
export interface AIProviderTextRequest {
  /** 请求唯一标识符 */
  requestId: string;
  /** 用户唯一标识符 */
  userId: string;
  /** 提示词 */
  prompt: string;
  /** AI 模型名称 */
  model: string;
  /** 最大输出 Token 数 */
  maxOutputTokens: number;
}

/**
 * AI 提供商结果接口
 */
export interface AIProviderResult {
  /** AI 返回的文本内容 */
  text: string;
  /** 使用的 AI 模型名称 */
  model: string;
  /** 输入 Token 数量 */
  inputTokenCount: number;
  /** 输出 Token 数量 */
  outputTokenCount: number;
  /** 预估费用 */
  estimatedCost: number;
}

/**
 * AI 提供商接口，定义 AI 服务调用规范
 */
export interface AIProvider {
  /**
   * 分析截图
   * @param request AI 请求参数
   * @returns AI 分析结果
   */
  analyzeScreenshot(request: AIProviderRequest): Promise<AIProviderResult>;

  /**
   * 分析文字
   * @param request AI 文字分析请求参数
   * @returns AI 分析结果
   */
  analyzeText(request: AIProviderTextRequest): Promise<AIProviderResult>;
}

/**
 * 后端应用接口，定义 HTTP 请求处理规范
 */
export interface BackendApp {
  /**
   * 处理 HTTP 请求
   * @param request HTTP 请求对象
   * @param env 环境变量
   * @returns HTTP 响应对象
   */
  fetch(request: Request, env: BackendEnv): Promise<Response>;
}

/**
 * 请求上下文接口，包含处理请求所需的所有信息
 */
interface RequestContext {
  /** HTTP 请求对象 */
  request: Request;
  /** 环境变量 */
  env: BackendEnv;
  /** 数据访问层实例 */
  repository: BackendRepository;
  /** AI 提供商实例 */
  aiProvider: AIProvider;
}

/**
 * 请求处理器类型，接收上下文并返回响应
 */
type Handler = (context: RequestContext) => Promise<Response>;

/**
 * 已认证请求上下文接口，继承 RequestContext 并包含用户信息
 */
interface AuthenticatedContext extends RequestContext {
  /** 已认证用户档案 */
  user: UserProfile;
}

/**
 * JSON 响应头，用于所有 API 响应
 */
const jsonHeaders = {
  "Content-Type": "application/json; charset=utf-8"
};

/**
 * 创建后端应用实例
 * @param repository 数据访问层实例
 * @param aiProvider AI 提供商实例，默认为未配置状态
 * @returns 后端应用实例
 */
export function createApp(repository: BackendRepository, aiProvider: AIProvider = unavailableAIProvider): BackendApp {
  return {
    async fetch(request, env) {
      return handleRequest({ request, env, repository, aiProvider });
    }
  };
}

/**
 * 处理 HTTP 请求的核心函数
 * 负责路由匹配、错误处理和请求分发
 * @param context 请求上下文
 * @returns HTTP 响应
 */
async function handleRequest(context: RequestContext): Promise<Response> {
  const url = new URL(context.request.url);
  const routeKey = `${context.request.method} ${url.pathname}`;
  const routes: Record<string, Handler> = {
    "GET /health": async () => json({ status: "ok" }),
    "POST /v1/auth/apple": handleAuthApple,
    "POST /v1/subscriptions/verify": withAuthenticatedUser(handleVerifySubscription),
    "GET /v1/subscriptions/status": withAuthenticatedUser(handleSubscriptionStatus),
    "GET /v1/usage/current": withAuthenticatedUser(handleUsageCurrent),
    "POST /v1/ai/analyze-screenshot": withAuthenticatedUser(handleAnalyzeScreenshot),
    "POST /v1/ai/analyze-text": withAuthenticatedUser(handleAnalyzeText),
    "POST /v1/apple/notifications": handleAppleNotification
  };

  const handler = routes[routeKey];
  if (!handler) {
    return json({ error: "not_found" }, 404);
  }

  try {
    return await handler(context);
  } catch (error) {
    console.error(
      JSON.stringify({
        event: "request_failed",
        route: routeKey,
        error: error instanceof Error ? error.message : "unknown"
      })
    );
    return json({ error: "internal_error" }, 500);
  }
}

/**
 * 创建未实现功能的处理器
 * 返回 501 Not Implemented 状态码
 * @param error 错误标识符
 * @returns 处理器函数
 */
function notImplemented(error: string): Handler {
  return async () => json({ error }, 501);
}

/**
 * 认证中间件，包装需要用户认证的处理器
 * 从请求头中提取 Bearer Token，验证用户身份
 * @param handler 需要认证的处理器
 * @returns 包装后的处理器
 */
function withAuthenticatedUser(
  handler: (context: AuthenticatedContext) => Promise<Response>
): Handler {
  return async (context) => {
    const token = bearerToken(context.request);
    if (!token) {
      return json({ error: "unauthorized" }, 401);
    }

    const user = await context.repository.findUserByBearerToken(token);
    if (!user) {
      return json({ error: "unauthorized" }, 401);
    }

    return handler({ ...context, user });
  };
}

/**
 * 处理获取订阅状态请求
 * @param context 已认证请求上下文
 * @returns 订阅状态响应
 */
async function handleSubscriptionStatus(context: AuthenticatedContext): Promise<Response> {
  const regionError = validateRegion(context.user, context.env);
  if (regionError) {
    return regionError;
  }

  const subscription = await context.repository.getSubscriptionStatus(context.user.id);
  return json({
    user_id: subscription.userId,
    status: subscription.status,
    product_id: subscription.productId,
    expires_at: subscription.expiresAt ?? null
  });
}

/**
 * 处理获取当前用量请求
 * @param context 已认证请求上下文
 * @returns 用量响应
 */
async function handleUsageCurrent(context: AuthenticatedContext): Promise<Response> {
  const regionError = validateRegion(context.user, context.env);
  if (regionError) {
    return regionError;
  }

  const usage = await context.repository.getUsage(context.user.id);
  return json({
    user_id: usage.userId,
    monthly_used_count: usage.monthlyUsedCount,
    monthly_limit_count: usage.monthlyLimitCount,
    daily_used_count: usage.dailyUsedCount,
    daily_limit_count: usage.dailyLimitCount
  });
}

/**
 * 处理 Apple Sign In 登录请求
 * 验证客户端传来的 Apple identity token（JWT），查找或创建用户，
 * 生成 Bearer Token 并返回给客户端
 * @param context 请求上下文（无需认证）
 * @returns 登录响应（含 Bearer Token）
 */
async function handleAuthApple(context: RequestContext): Promise<Response> {
  // 解析请求体
  const body = await parseJsonBody(context.request);
  if (!body || typeof body.identity_token !== "string" || !body.identity_token.trim()) {
    console.error(JSON.stringify({ event: "auth_apple_invalid_request", reason: "missing or invalid identity_token" }));
    return json({ error: "invalid_request" }, 400);
  }

  const identityToken = body.identity_token.trim();
  const storefront = typeof body.storefront === "string" ? body.storefront.trim() : undefined;

  console.log(JSON.stringify({ 
    event: "auth_apple_start", 
    identity_token_length: identityToken.length, 
    storefront, 
    bundle_id: context.env.APPLE_BUNDLE_ID 
  }));

  // 验证 Apple JWT
  let claims: { sub: string; email?: string; emailVerified?: boolean };
  try {
    claims = await verifyAppleJWT(identityToken, context.env.APPLE_BUNDLE_ID);
    console.log(JSON.stringify({ 
      event: "auth_apple_jwt_verified", 
      claims: { sub: claims.sub, email: claims.email } 
    }));
  } catch (error) {
    console.error(
      JSON.stringify({
        event: "apple_jwt_verification_failed",
        error: error instanceof Error ? error.message : "unknown"
      })
    );
    return json({ error: "authentication_failed" }, 401);
  }

  // 查找或创建用户（传入 storefront）
  const user = await context.repository.findOrCreateUser(claims.sub, claims.email, storefront);
  console.log(JSON.stringify({ event: "auth_apple_user_found_or_created", user_id: user.id }));

  // 创建会话并生成 Bearer Token
  const token = await context.repository.createSession(user.id);
  console.log(JSON.stringify({ event: "auth_apple_session_created", token_prefix: token.substring(0, 20) + "..." }));

  // 返回响应
  return json({
    token,
    user_id: user.id
  });
}

/**
 * 处理 App Store 订阅收据验证请求
 * 客户端调用 StoreKit 购买成功后，传入 signedTransaction（Apple 签名的 JWT），
 * 后端验证签名并提取交易信息写入 subscriptions 表
 * @param context 已认证请求上下文
 * @returns 订阅验证结果响应
 */
async function handleVerifySubscription(context: AuthenticatedContext): Promise<Response> {
  // 解析请求体
  const body = await parseJsonBody(context.request);
  if (!body || typeof body.signed_transaction !== "string" || !body.signed_transaction.trim()) {
    return json({ error: "invalid_request" }, 400);
  }

  const signedTransaction = body.signed_transaction.trim();

  // 验证 StoreKit JWT 签名并提取交易信息
  let transaction: StoreKitTransactionPayload;
  try {
    transaction = await verifyStoreKitTransactionJWT(
      signedTransaction,
      context.env.APPLE_BUNDLE_ID,
      appStoreSignedDataConfig(context.env)
    );
  } catch (error) {
    console.error(
      JSON.stringify({
        event: "storekit_jwt_verification_failed",
        error: error instanceof Error ? error.message : "unknown"
      })
    );
    return json({ error: "verification_failed" }, 401);
  }

  if (transaction.productId !== AI_PRO_MONTHLY_PRODUCT_ID) {
    console.error(
      JSON.stringify({
        event: "storekit_unknown_product",
        product_id: transaction.productId
      })
    );
    return json({ error: "invalid_product" }, 400);
  }

  // StoreKit 购买时，App 会把当前后端用户 UUID 作为 appAccountToken 写入 Apple 交易。
  // 只有交易中的账号令牌与 Bearer Token 对应用户一致时才能授予订阅，避免其他登录用户
  // 重放一份真实但不属于自己的 signed transaction 来认领 AI Pro 权限。
  const transactionAccountToken = transaction.appAccountToken?.trim().toLowerCase();
  const authenticatedUserId = context.user.id.trim().toLowerCase();
  if (!transactionAccountToken || transactionAccountToken !== authenticatedUserId) {
    console.error(
      JSON.stringify({
        event: "storekit_app_account_token_mismatch",
        transaction_id: transaction.transactionId,
        has_app_account_token: Boolean(transactionAccountToken)
      })
    );
    return json({ error: "transaction_account_mismatch" }, 403);
  }

  // 判断订阅状态：根据 expiresDate 判断是否有效
  const now = Date.now();
  const status = transaction.expiresDate && transaction.expiresDate > now ? "active" : "expired";

  // 写入数据库
  await context.repository.createOrUpdateSubscription(context.user.id, {
    originalTransactionId: transaction.originalTransactionId,
    latestTransactionId: transaction.transactionId,
    productId: transaction.productId,
    environment: transaction.environment,
    expiresAt: transaction.expiresDate ? new Date(transaction.expiresDate).toISOString() : null
  });

  // 返回响应
  return json({
    status,
    product_id: transaction.productId,
    transaction_id: transaction.transactionId,
    expires_at: transaction.expiresDate ? new Date(transaction.expiresDate).toISOString() : null,
    environment: transaction.environment
  });
}

/**
 * 处理 App Store Server 通知回调（webhook）
 *
 * Apple 服务器在订阅状态变更时主动推送通知到这个端点。
 * 不需要 Bearer Token 认证，Apple 用 JWT 签名保证真实性。
 * 无论处理是否成功，始终返回 200 以确认收到通知。
 * @param context 请求上下文
 * @returns 确认响应
 */
async function handleAppleNotification(context: RequestContext): Promise<Response> {
  // 解析请求体
  const body = await parseJsonBody(context.request);
  const signedPayload = typeof body?.signedPayload === "string" ? body.signedPayload.trim() : "";
  if (!signedPayload) {
    console.error(JSON.stringify({ event: "apple_notification_missing_signed_payload" }));
    return json({}, 200);
  }

  // 验证通知 JWT 签名
  let notification: AppStoreNotificationPayload;
  try {
    notification = await verifyAppStoreNotificationJWT(
      signedPayload,
      context.env.APPLE_BUNDLE_ID,
      appStoreSignedDataConfig(context.env)
    );
  } catch (error) {
    console.error(
      JSON.stringify({
        event: "apple_notification_verification_failed",
        error: error instanceof Error ? error.message : "unknown"
      })
    );
    return json({}, 200);
  }

  // 验证交易信息 JWT 并提取交易数据
  let transaction: StoreKitTransactionPayload;
  try {
    transaction = await verifyStoreKitTransactionJWT(
      notification.signedTransactionInfo,
      context.env.APPLE_BUNDLE_ID,
      appStoreSignedDataConfig(context.env)
    );
  } catch (error) {
    console.error(
      JSON.stringify({
        event: "apple_notification_transaction_verification_failed",
        error: error instanceof Error ? error.message : "unknown"
      })
    );
    return json({}, 200);
  }

  if (transaction.productId !== AI_PRO_MONTHLY_PRODUCT_ID) {
    console.error(
      JSON.stringify({
        event: "apple_notification_unknown_product",
        product_id: transaction.productId
      })
    );
    return json({}, 200);
  }

  // 通知类型 → 订阅状态映射
  const status = notificationTypeToStatus(notification.notificationType, notification.subtype);

  // 写入数据库（若无 appAccountToken 则无法关联用户，跳过）
  if (transaction.appAccountToken) {
    try {
      await context.repository.createOrUpdateSubscription(transaction.appAccountToken, {
        originalTransactionId: transaction.originalTransactionId,
        latestTransactionId: transaction.transactionId,
        productId: transaction.productId,
        environment: transaction.environment,
        expiresAt: transaction.expiresDate ? new Date(transaction.expiresDate).toISOString() : null,
        status
      });
    } catch (error) {
      console.error(
        JSON.stringify({
          event: "apple_notification_update_subscription_failed",
          user_id: transaction.appAccountToken,
          error: error instanceof Error ? error.message : "unknown"
        })
      );
    }
  } else {
    console.error(
      JSON.stringify({
        event: "apple_notification_missing_app_account_token",
        notification_type: notification.notificationType,
        transaction_id: transaction.transactionId
      })
    );
  }

  // 始终返回 200
  return json({}, 200);
}

/**
 * App Store Server 通知类型 → subscription status 映射
 */
function notificationTypeToStatus(notificationType: string, _subtype?: string): SubscriptionStatus {
  switch (notificationType) {
    case "SUBSCRIBED":
    case "DID_RENEW":
    case "DID_CHANGE_RENEWAL_PREF":
    case "DID_CHANGE_RENEWAL_STATUS":
    case "INITIAL_BUY":
    case "INTERACTIVE_RENEWAL":
      return "active";
    case "DID_FAIL_TO_RENEW":
    case "EXPIRED":
      return "expired";
    case "REFUND":
    case "REVOKE":
      return "refunded";
    case "GRACE_PERIOD_EXPIRED":
    case "RENEWAL_EXTENDED":
    default:
      return "grace_period";
  }
}

/**
 * 处理 AI 截图分析请求
 * 执行完整的请求流程：地区验证 -> 订阅验证 -> 配额验证 -> 请求格式验证 ->
 * 幂等性检查 -> 图片大小验证 -> AI 调用 -> 用量记录 -> 配额更新
 * @param context 已认证请求上下文
 * @returns AI 分析结果响应
 */
async function handleAnalyzeScreenshot(context: AuthenticatedContext): Promise<Response> {
  // 验证地区权限
  const regionError = validateRegion(context.user, context.env);
  if (regionError) {
    return regionError;
  }

  // 验证订阅状态（必须是 active 或 grace_period）
  if (context.user.subscriptionStatus !== "active" && context.user.subscriptionStatus !== "grace_period") {
    return json({ error: "subscription_required" }, 402);
  }

  // 验证日/月配额
  const quotaError = validateQuota(context.user, context.env);
  if (quotaError) {
    return quotaError;
  }

  // 解析请求体
  const body = await parseJsonBody(context.request);
  if (!body || typeof body.request_id !== "string" || typeof body.image_base64 !== "string") {
    return json({ error: "invalid_request" }, 400);
  }

  // 验证 request_id
  const requestId = body.request_id.trim();
  if (!requestId) {
    return json({ error: "invalid_request" }, 400);
  }

  // 幂等性检查：防止重复请求
  const existingRecord = await context.repository.findUsageRecordByRequestId(context.user.id, requestId);
  if (existingRecord) {
    return json({ error: "duplicate_request", status: existingRecord.status }, 409);
  }

  // 验证图片大小
  const imageBytes = estimateBase64Bytes(body.image_base64);
  if (imageBytes > numberFromEnv(context.env.MAX_IMAGE_BYTES, 2_097_152)) {
    return json({ error: "image_too_large" }, 413);
  }

  // 准备 AI 请求参数
  const model = context.env.AI_MODEL || "gpt-5.4-mini";
  const prompt = typeof body.prompt === "string" && body.prompt.trim()
    ? body.prompt.trim()
    : "Analyze this screenshot. Explain the likely context, key text, and actionable next steps.";

  // 调用 AI 提供商
  let result: AIProviderResult;
  try {
    result = await context.aiProvider.analyzeScreenshot({
      requestId,
      userId: context.user.id,
      imageBase64: body.image_base64,
      prompt,
      model,
      maxOutputTokens: numberFromEnv(context.env.AI_MAX_OUTPUT_TOKENS, 1200)
    });
  } catch (error) {
    const unsupportedInput = isAIProviderUnsupportedInputError(error);
    console.error(
      JSON.stringify({
        event: unsupportedInput ? "ai_provider_input_unsupported" : "ai_provider_failed",
        request_id: requestId,
        user_id: context.user.id,
        model,
        error: error instanceof Error ? error.message : "AI provider failed"
      })
    );
    // AI 调用失败，记录为不可计费的失败请求
    await context.repository.recordUsage({
      userId: context.user.id,
      requestId,
      requestType: "analyze_screenshot",
      model,
      imageBytes,
      imageCount: 1,
      inputTokenCount: 0,
      outputTokenCount: 0,
      estimatedCost: 0,
      billable: false,
      status: "failed",
      outputText: error instanceof Error ? error.message : "AI provider failed"
    });
    return json({ error: unsupportedInput ? "ai_provider_input_unsupported" : "ai_provider_failed" }, unsupportedInput ? 422 : 502);
  }

  // AI 调用成功，记录用量并更新配额
  const tokenCount = result.inputTokenCount + result.outputTokenCount;
  await context.repository.recordUsage({
    userId: context.user.id,
    requestId,
    requestType: "analyze_screenshot",
    model: result.model,
    imageBytes,
    imageCount: 1,
    inputTokenCount: result.inputTokenCount,
    outputTokenCount: result.outputTokenCount,
    estimatedCost: result.estimatedCost,
    billable: true,
    status: "succeeded",
    outputText: result.text
  });
  await context.repository.incrementMonthlyQuota(context.user.id, 1, tokenCount, result.estimatedCost);

  // 返回成功响应
  return json({
    request_id: requestId,
    analysis: result.text,
    model: result.model,
    usage: {
      input_tokens: result.inputTokenCount,
      output_tokens: result.outputTokenCount
    }
  });
}

/**
 * 处理 AI 文字分析请求
 * 执行完整的请求流程：地区验证 -> 订阅验证 -> 配额验证 -> 请求格式验证 ->
 * 幂等性检查 -> AI 调用 -> 用量记录 -> 配额更新
 * @param context 已认证请求上下文
 * @returns AI 分析结果响应
 */
async function handleAnalyzeText(context: AuthenticatedContext): Promise<Response> {
  // 验证地区权限
  const regionError = validateRegion(context.user, context.env);
  if (regionError) {
    return regionError;
  }

  // 验证订阅状态（必须是 active 或 grace_period）
  if (context.user.subscriptionStatus !== "active" && context.user.subscriptionStatus !== "grace_period") {
    return json({ error: "subscription_required" }, 402);
  }

  // 验证日/月配额
  const quotaError = validateQuota(context.user, context.env);
  if (quotaError) {
    return quotaError;
  }

  // 解析请求体
  const body = await parseJsonBody(context.request);
  if (!body || typeof body.request_id !== "string") {
    return json({ error: "invalid_request" }, 400);
  }

  // 验证 request_id
  const requestId = body.request_id.trim();
  if (!requestId) {
    return json({ error: "invalid_request" }, 400);
  }

  // 幂等性检查：防止重复请求
  const existingRecord = await context.repository.findUsageRecordByRequestId(context.user.id, requestId);
  if (existingRecord) {
    return json({ error: "duplicate_request", status: existingRecord.status }, 409);
  }

  // 准备 AI 请求参数
  const model = context.env.AI_MODEL || "gpt-5.4-mini";
  const prompt = typeof body.prompt === "string" && body.prompt.trim()
    ? body.prompt.trim()
    : "请分析以下内容并给出有价值的见解。";

  // 调用 AI 提供商
  let result: AIProviderResult;
  try {
    result = await context.aiProvider.analyzeText({
      requestId,
      userId: context.user.id,
      prompt,
      model,
      maxOutputTokens: numberFromEnv(context.env.AI_MAX_OUTPUT_TOKENS, 1200)
    });
  } catch (error) {
    console.error(
      JSON.stringify({
        event: "ai_provider_failed",
        request_id: requestId,
        user_id: context.user.id,
        model,
        error: error instanceof Error ? error.message : "AI provider failed"
      })
    );
    // AI 调用失败，记录为不可计费的失败请求
    await context.repository.recordUsage({
      userId: context.user.id,
      requestId,
      requestType: "analyze_text",
      model,
      imageBytes: 0,
      imageCount: 0,
      inputTokenCount: 0,
      outputTokenCount: 0,
      estimatedCost: 0,
      billable: false,
      status: "failed",
      outputText: error instanceof Error ? error.message : "AI provider failed"
    });
    return json({ error: "ai_provider_failed" }, 502);
  }

  // AI 调用成功，记录用量并更新配额
  const tokenCount = result.inputTokenCount + result.outputTokenCount;
  await context.repository.recordUsage({
    userId: context.user.id,
    requestId,
    requestType: "analyze_text",
    model: result.model,
    imageBytes: 0,
    imageCount: 0,
    inputTokenCount: result.inputTokenCount,
    outputTokenCount: result.outputTokenCount,
    estimatedCost: result.estimatedCost,
    billable: true,
    status: "succeeded",
    outputText: result.text
  });
  await context.repository.incrementMonthlyQuota(context.user.id, 1, tokenCount, result.estimatedCost);

  // 返回成功响应
  return json({
    request_id: requestId,
    analysis: result.text,
    model: result.model,
    usage: {
      input_tokens: result.inputTokenCount,
      output_tokens: result.outputTokenCount
    }
  });
}

function isAIProviderUnsupportedInputError(error: unknown): boolean {
  return error instanceof Error && (error as { code?: string }).code === "ai_provider_input_unsupported";
}

/**
 * 验证用户地区是否在白名单中
 * CHN、未知或缺失的地区将被阻止
 * @param user 用户档案
 * @param env 环境变量
 * @returns 错误响应或 null（验证通过）
 */
function validateRegion(user: UserProfile, env: BackendEnv): Response | null {
  const storefront = user.storefront?.trim().toUpperCase();
  if (!storefront || storefront === "CHN") {
    return json({ error: "region_unavailable" }, 403);
  }

  const allowedStorefronts = new Set(
    env.ALLOWED_STOREFRONTS.split(",")
      .map((value) => value.trim().toUpperCase())
      .filter(Boolean)
  );

  if (!allowedStorefronts.has(storefront)) {
    return json({ error: "region_unavailable" }, 403);
  }

  return null;
}

function appStoreSignedDataConfig(env: BackendEnv): AppStoreSignedDataVerificationConfig {
  return {
    ...(env.APPLE_ROOT_CERTIFICATES_PEM !== undefined
      ? { rootCertificatesPem: env.APPLE_ROOT_CERTIFICATES_PEM }
      : {}),
    ...(env.APPLE_APP_ID !== undefined ? { appAppleId: env.APPLE_APP_ID } : {}),
    ...(parseBooleanEnv(env.ALLOW_LOCAL_STOREKIT_TRANSACTIONS)
      ? { allowLocalTestingTransactions: true }
      : {})
  };
}

function parseBooleanEnv(value?: string): boolean {
  if (!value) {
    return false;
  }
  return value.trim().toLowerCase() === "true" || value.trim() === "1";
}

/**
 * 验证用户是否还有可用配额
 * @param user 用户档案
 * @param env 环境变量
 * @returns 错误响应或 null（验证通过）
 */
function validateQuota(user: UserProfile, env: BackendEnv): Response | null {
  const monthlyLimit = numberFromEnv(env.MONTHLY_REQUEST_LIMIT, 100);
  const dailyLimit = numberFromEnv(env.DAILY_REQUEST_LIMIT, 20);
  if (user.monthlyUsedCount >= monthlyLimit) {
    return json({ error: "monthly_quota_exceeded" }, 429);
  }
  if (user.dailyUsedCount >= dailyLimit) {
    return json({ error: "daily_quota_exceeded" }, 429);
  }
  return null;
}

/**
 * 从请求头中提取 Bearer Token
 * @param request HTTP 请求对象
 * @returns Token 字符串或 null
 */
function bearerToken(request: Request): string | null {
  const authorization = request.headers.get("Authorization");
  const match = authorization?.match(/^Bearer\s+(.+)$/i);
  return match?.[1]?.trim() || null;
}

/**
 * 解析 JSON 请求体
 * @param request HTTP 请求对象
 * @returns 解析后的对象或 null（解析失败）
 */
async function parseJsonBody(request: Request): Promise<Record<string, unknown> | null> {
  try {
    return (await request.json()) as Record<string, unknown>;
  } catch {
    return null;
  }
}

/**
 * 估算 Base64 编码字符串的原始字节大小
 * @param value Base64 编码字符串
 * @returns 原始字节数
 */
function estimateBase64Bytes(value: string): number {
  const normalized = value.replace(/^data:[^,]+,/, "").replace(/\s/g, "");
  const padding = normalized.endsWith("==") ? 2 : normalized.endsWith("=") ? 1 : 0;
  return Math.max(0, Math.floor((normalized.length * 3) / 4) - padding);
}

/**
 * 从环境变量中解析数字
 * @param value 环境变量值
 * @param fallback 默认值
 * @returns 解析后的数字或默认值
 */
function numberFromEnv(value: string, fallback: number): number {
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

/**
 * 创建 JSON 响应
 * @param body 响应体对象
 * @param status HTTP 状态码，默认为 200
 * @returns HTTP 响应对象
 */
function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: jsonHeaders
  });
}

/**
 * 未配置的 AI 提供商，用于默认值
 * 调用时会抛出错误
 */
const unavailableAIProvider: AIProvider = {
  async analyzeScreenshot() {
    throw new Error("AI provider is not configured");
  },
  async analyzeText() {
    throw new Error("AI provider is not configured");
  }
};
