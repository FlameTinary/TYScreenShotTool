/**
 * TShot AI 后端应用测试套件
 * 测试核心业务逻辑：认证、地区限制、订阅验证、配额检查、AI 调用和用量记录
 */

import { beforeEach, describe, expect, it, vi } from "vitest";

const appleAuthMocks = vi.hoisted(() => {
  const storeKitPayload = () => ({
    transactionId: "test-txn-001",
    originalTransactionId: "test-original-txn-001",
    productId: "tshot.pro.monthly",
    bundleId: "com.tshot.app",
    environment: "Sandbox" as const,
    expiresDate: Date.now() + 86400000,
    purchaseDate: Date.now(),
    signedDate: Date.now(),
    appAccountToken: "old-user-id-from-storekit"
  });

  return {
    verifyAppleJWT: vi.fn(() => Promise.resolve({ sub: "test-apple-user-001", email: "test@example.com" })),
    verifyStoreKitTransactionJWT: vi.fn(() => Promise.resolve(storeKitPayload())),
    verifyAppStoreNotificationJWT: vi.fn(() => Promise.resolve({
      notificationType: "DID_RENEW",
      subtype: undefined,
      bundleId: "com.tshot.app",
      environment: "Sandbox" as const,
      signedTransactionInfo: "mock-transaction-jwt",
      notificationUUID: "test-uuid-001",
      signedDate: Date.now()
    })),
    resetAppleKeyCache: vi.fn()
  };
});

vi.mock("../src/appleAuth", () => appleAuthMocks);

import { createApp,
  type AIProvider,
  type BackendEnv,
  type BackendRepository,
  type SubscriptionTransactionInput,
  type UsageRecordInput,
  type UserProfile
} from "../src/app";

beforeEach(() => {
  appleAuthMocks.verifyAppleJWT.mockClear();
  appleAuthMocks.verifyStoreKitTransactionJWT.mockClear();
  appleAuthMocks.verifyAppStoreNotificationJWT.mockClear();
  appleAuthMocks.resetAppleKeyCache.mockClear();
});

/**
 * 默认环境变量配置
 */
const defaultEnv: BackendEnv = {
  ALLOWED_STOREFRONTS: "USA,JPN",
  MONTHLY_REQUEST_LIMIT: "100",
  DAILY_REQUEST_LIMIT: "20",
  MAX_IMAGE_BYTES: "2097152",
  AI_MODEL: "gpt-5.4-mini",
  AI_MAX_OUTPUT_TOKENS: "1200",
  APPLE_BUNDLE_ID: "com.tshot.app"
};

/**
 * 创建测试用户
 * @param overrides 用户属性覆盖（可选）
 * @returns 用户档案对象
 */
function user(overrides: Partial<UserProfile> = {}): UserProfile {
  return {
    id: "user_1",
    storefront: "USA",
    countryCode: "US",
    subscriptionStatus: "active",
    monthlyUsedCount: 3,
    dailyUsedCount: 1,
    ...overrides
  };
}

/**
 * 创建测试用的数据访问层 mock
 * @param profile 用户档案（null 表示认证失败）
 * @param options 配置选项
 * @param options.existingRequestId 已存在的请求 ID（用于测试幂等性）
 * @param options.usageRecords 用量记录数组（用于收集记录）
 * @param options.quotaIncrements 配额增量数组（用于收集增量）
 * @returns Mock 的 BackendRepository
 */
function repository(profile: UserProfile | null, options: {
  existingRequestId?: string;
  usageRecords?: UsageRecordInput[];
  quotaIncrements?: Array<{ userId: string; requestCount: number; tokenCount: number; cost: number }>;
  /** 模拟 findOrCreateUser 返回的用户 ID */
  createdUserId?: string;
  /** 模拟 createSession 返回的 token */
  createdToken?: string;
  /** 收集 Apple 登录传入的数据 */
  authInputs?: Array<{ appleUserId: string; email?: string; storefront?: string }>;
  /** 收集订阅写入数据 */
  subscriptionWrites?: Array<{ userId: string; transaction: SubscriptionTransactionInput }>;
  /** 模拟订阅写入失败 */
  subscriptionWriteError?: Error;
} = {}): BackendRepository {
  return {
    async findUserByBearerToken() {
      return profile;
    },
    async findUsageRecordByRequestId(_userId: string, requestId: string) {
      if (options.existingRequestId === requestId) {
        return {
          requestId,
          status: "succeeded"
        };
      }
      return null;
    },
    async getUsage(userId: string) {
      return {
        userId,
        monthlyUsedCount: profile?.monthlyUsedCount ?? 0,
        monthlyLimitCount: 100,
        dailyUsedCount: profile?.dailyUsedCount ?? 0,
        dailyLimitCount: 20
      };
    },
    async getSubscriptionStatus(userId: string) {
      return {
        userId,
        status: profile?.subscriptionStatus ?? "inactive",
        productId: "tshot.pro.monthly"
      };
    },
    async recordUsage(record: UsageRecordInput) {
      options.usageRecords?.push(record);
    },
    async incrementMonthlyQuota(userId: string, requestCount: number, tokenCount: number, cost: number) {
      options.quotaIncrements?.push({ userId, requestCount, tokenCount, cost });
    },
    async findOrCreateUser(appleUserId: string, email?: string, storefront?: string) {
      options.authInputs?.push({
        appleUserId,
        ...(email !== undefined ? { email } : {}),
        ...(storefront !== undefined ? { storefront } : {})
      });
      return profile ?? {
        id: options.createdUserId ?? "new_user_1",
        storefront: null,
        countryCode: null,
        subscriptionStatus: "inactive" as const,
        monthlyUsedCount: 0,
        dailyUsedCount: 0
      };
    },
    async createSession(_userId: string) {
      return options.createdToken ?? "mock-session-token-001";
    },
    async createOrUpdateSubscription(userId: string, transaction: SubscriptionTransactionInput) {
      if (options.subscriptionWriteError) {
        throw options.subscriptionWriteError;
      }
      options.subscriptionWrites?.push({ userId, transaction });
    }
  };
}

/**
 * 创建测试用的 AI 提供商 mock
 * @param options 配置选项
 * @param options.calls 调用次数计数器
 * @param options.error 模拟错误（可选）
 * @returns Mock 的 AIProvider
 */
function aiProvider(options: {
  calls?: number[];
  error?: Error;
} = {}): AIProvider {
  return {
    async analyzeScreenshot() {
      options.calls?.push(1);
      if (options.error) {
        throw options.error;
      }
      return {
        text: "This screenshot shows a Swift build error and suggests checking the module import.",
        model: "gpt-5.4-mini",
        inputTokenCount: 80,
        outputTokenCount: 24,
        estimatedCost: 0.00042
      };
    },
    async analyzeText() {
      options.calls?.push(1);
      if (options.error) {
        throw options.error;
      }
      return {
        text: "REST API 是一种基于 HTTP 协议的架构风格，用于构建 Web 服务。",
        model: "gpt-5.4-mini",
        inputTokenCount: 35,
        outputTokenCount: 60,
        estimatedCost: 0.00015
      };
    }
  };
}

/**
 * 解析响应体为 JSON 对象
 * @param response HTTP 响应对象
 * @returns JSON 对象
 */
async function json(response: Response) {
  return response.json() as Promise<Record<string, unknown>>;
}

describe("TShot AI backend app", () => {
  /**
   * 测试：没有 Authorization 头的请求应被拒绝
   */
  it("rejects usage requests without Authorization", async () => {
    const app = createApp(repository(user()));

    const response = await app.fetch(new Request("https://api.example.com/v1/usage/current"), defaultEnv);

    expect(response.status).toBe(401);
    await expect(json(response)).resolves.toMatchObject({
      error: "unauthorized"
    });
  });

  /**
   * 测试：Apple Sign In 缺少 identity_token 应返回 400
   */
  it("rejects Apple Sign In without identity_token", async () => {
    const app = createApp(repository(user()));

    const response = await app.fetch(
      new Request("https://api.example.com/v1/auth/apple", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({})
      }),
      defaultEnv
    );

    expect(response.status).toBe(400);
    await expect(json(response)).resolves.toMatchObject({
      error: "invalid_request"
    });
  });

  /**
   * 测试：Apple Sign In 返回 token 和 user_id
   * 验证新用户的创建和 token 返回
   */
  it("returns token and user_id from Apple Sign In for a new user", async () => {
    const authInputs: Array<{ appleUserId: string; email?: string; storefront?: string }> = [];
    const app = createApp(
      repository(null, {
        createdUserId: "apple-new-user-001",
        createdToken: "apple-token-abc",
        authInputs
      })
    );

    const response = await app.fetch(
      new Request("https://api.example.com/v1/auth/apple", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ identity_token: "header.payload.signature", storefront: "USA" })
      }),
      { ...defaultEnv, APPLE_BUNDLE_ID: "com.tshot.app" }
    );

    expect(response.status).toBe(200);
    const body = await json(response);
    expect(body).toMatchObject({
      token: "apple-token-abc",
      user_id: "apple-new-user-001"
    });
    // token 应为字符串且非空
    expect(typeof body.token).toBe("string");
    expect((body.token as string).length).toBeGreaterThan(0);
    expect(authInputs).toEqual([
      {
        appleUserId: "test-apple-user-001",
        email: "test@example.com",
        storefront: "USA"
      }
    ]);
  });

  /**
   * 测试：Apple Sign In 已存在的用户应返回新的 token
   */
  it("returns a session token for an existing user via Apple Sign In", async () => {
    const app = createApp(
      repository(user({ id: "existing-user-001" }), { createdToken: "existing-session-token" })
    );

    const response = await app.fetch(
      new Request("https://api.example.com/v1/auth/apple", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ identity_token: "header.payload.signature" })
      }),
      { ...defaultEnv, APPLE_BUNDLE_ID: "com.tshot.app" }
    );

    expect(response.status).toBe(200);
    await expect(json(response)).resolves.toMatchObject({
      token: "existing-session-token",
      user_id: "existing-user-001"
    });
  });

  /**
   * 测试：订阅验证请求缺少 signed_transaction 应返回 400
   */
  it("rejects subscription verify without signed_transaction", async () => {
    const app = createApp(repository(user({ storefront: "USA", subscriptionStatus: "active" })));

    const response = await app.fetch(
      new Request("https://api.example.com/v1/subscriptions/verify", {
        method: "POST",
        headers: {
          Authorization: "Bearer test-token",
          "Content-Type": "application/json"
        },
        body: JSON.stringify({})
      }),
      defaultEnv
    );

    expect(response.status).toBe(400);
    await expect(json(response)).resolves.toMatchObject({
      error: "invalid_request"
    });
  });

  /**
   * 测试：订阅验证请求无认证应返回 401
   */
  it("rejects subscription verify without Authorization", async () => {
    const app = createApp(repository(user()));

    const response = await app.fetch(
      new Request("https://api.example.com/v1/subscriptions/verify", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ signed_transaction: "header.payload.signature" })
      }),
      defaultEnv
    );

    expect(response.status).toBe(401);
    await expect(json(response)).resolves.toMatchObject({
      error: "unauthorized"
    });
  });

  /**
   * 测试：成功验证有效订阅并返回订阅状态
   */
  it("verifies a valid subscription successfully", async () => {
    const app = createApp(repository(user({ storefront: "USA", subscriptionStatus: "active" })));

    const response = await app.fetch(
      new Request("https://api.example.com/v1/subscriptions/verify", {
        method: "POST",
        headers: {
          Authorization: "Bearer test-token",
          "Content-Type": "application/json"
        },
        body: JSON.stringify({ signed_transaction: "valid.storekit.jwt" })
      }),
      { ...defaultEnv, APPLE_BUNDLE_ID: "com.tshot.app" }
    );

    expect(response.status).toBe(200);
    const body = await json(response);
    expect(body).toMatchObject({
      status: "active",
      product_id: "tshot.pro.monthly",
      transaction_id: "test-txn-001",
      environment: "Sandbox"
    });
    expect(typeof body.expires_at).toBe("string");
  });

  /**
   * 测试：客户端恢复购买时，订阅应写给当前 Bearer Token 对应的登录用户。
   * 这覆盖删除 Supabase 用户 / 订阅后重新登录生成新 user_id 的恢复场景。
   */
  it("claims a restored subscription for the currently authenticated user", async () => {
    const subscriptionWrites: Array<{ userId: string; transaction: SubscriptionTransactionInput }> = [];
    const app = createApp(
      repository(
        user({
          id: "new-user-after-db-reset",
          storefront: "USA",
          subscriptionStatus: "inactive"
        }),
        { subscriptionWrites }
      )
    );

    const response = await app.fetch(
      new Request("https://api.example.com/v1/subscriptions/verify", {
        method: "POST",
        headers: {
          Authorization: "Bearer test-token",
          "Content-Type": "application/json"
        },
        body: JSON.stringify({ signed_transaction: "valid.storekit.jwt" })
      }),
      { ...defaultEnv, APPLE_BUNDLE_ID: "com.tshot.app" }
    );

    expect(response.status).toBe(200);
    expect(subscriptionWrites).toHaveLength(1);
    expect(subscriptionWrites[0]).toMatchObject({
      userId: "new-user-after-db-reset",
      transaction: {
        originalTransactionId: "test-original-txn-001",
        latestTransactionId: "test-txn-001",
        productId: "tshot.pro.monthly",
        environment: "Sandbox"
      }
    });
  });

  it("rejects subscription verification for products outside AI Pro", async () => {
    appleAuthMocks.verifyStoreKitTransactionJWT.mockResolvedValueOnce({
      transactionId: "other-txn-001",
      originalTransactionId: "other-original-txn-001",
      productId: "other.product",
      bundleId: "com.tshot.app",
      environment: "Sandbox",
      expiresDate: Date.now() + 86400000,
      purchaseDate: Date.now(),
      signedDate: Date.now(),
      appAccountToken: "new-user-after-db-reset"
    });
    const subscriptionWrites: Array<{ userId: string; transaction: SubscriptionTransactionInput }> = [];
    const app = createApp(
      repository(
        user({
          id: "new-user-after-db-reset",
          storefront: "USA",
          subscriptionStatus: "inactive"
        }),
        { subscriptionWrites }
      )
    );

    const response = await app.fetch(
      new Request("https://api.example.com/v1/subscriptions/verify", {
        method: "POST",
        headers: {
          Authorization: "Bearer test-token",
          "Content-Type": "application/json"
        },
        body: JSON.stringify({ signed_transaction: "valid.other-product.jwt" })
      }),
      { ...defaultEnv, APPLE_BUNDLE_ID: "com.tshot.app" }
    );

    expect(response.status).toBe(400);
    expect(await json(response)).toMatchObject({ error: "invalid_product" });
    expect(subscriptionWrites).toHaveLength(0);
  });

  /**
   * 测试：只有开发环境显式打开本地 StoreKit 开关时，才把 Xcode / LocalTesting
   * 交易许可传给 Apple signed data 校验器。
   */
  it("passes local StoreKit verification opt-in to subscription verification", async () => {
    const app = createApp(repository(user({ storefront: "USA", subscriptionStatus: "inactive" })));

    const response = await app.fetch(
      new Request("https://api.example.com/v1/subscriptions/verify", {
        method: "POST",
        headers: {
          Authorization: "Bearer test-token",
          "Content-Type": "application/json"
        },
        body: JSON.stringify({ signed_transaction: "valid.xcode.storekit.jwt" })
      }),
      {
        ...defaultEnv,
        APPLE_BUNDLE_ID: "com.tshot.app",
        ALLOW_LOCAL_STOREKIT_TRANSACTIONS: "true"
      }
    );

    expect(response.status).toBe(200);
    expect(appleAuthMocks.verifyStoreKitTransactionJWT).toHaveBeenLastCalledWith(
      "valid.xcode.storekit.jwt",
      "com.tshot.app",
      expect.objectContaining({ allowLocalTestingTransactions: true })
    );
  });

  /**
   * 测试：缺失 signedPayload 的通知应返回 200（Apple 期望确认）
   */
  it("returns 200 for Apple notification without signedPayload", async () => {
    const usageRecords: import("../src/app").UsageRecordInput[] = [];
    const app = createApp(repository(user(), { usageRecords }));

    const response = await app.fetch(
      new Request("https://api.example.com/v1/apple/notifications", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({})
      }),
      { ...defaultEnv, APPLE_BUNDLE_ID: "com.tshot.app" }
    );

    // Apple 期望 200 确认收到，即使 payload 无效
    expect(response.status).toBe(200);
  });

  /**
   * 测试：有效通知应返回 200 并调用 createOrUpdateSubscription
   */
  it("processes a valid Apple notification and returns 200", async () => {
    const app = createApp(repository(user()));

    const response = await app.fetch(
      new Request("https://api.example.com/v1/apple/notifications", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          signedPayload: "valid.notification.jwt"
        })
      }),
      { ...defaultEnv, APPLE_BUNDLE_ID: "com.tshot.app" }
    );

    // 始终返回 200 确认收到
    expect(response.status).toBe(200);
  });

  it("ignores Apple notifications for products outside AI Pro", async () => {
    appleAuthMocks.verifyStoreKitTransactionJWT.mockResolvedValueOnce({
      transactionId: "other-txn-001",
      originalTransactionId: "other-original-txn-001",
      productId: "other.product",
      bundleId: "com.tshot.app",
      environment: "Sandbox",
      expiresDate: Date.now() + 86400000,
      purchaseDate: Date.now(),
      signedDate: Date.now(),
      appAccountToken: "old-user-id-from-storekit"
    });
    const subscriptionWrites: Array<{ userId: string; transaction: SubscriptionTransactionInput }> = [];
    const app = createApp(repository(user(), { subscriptionWrites }));

    const response = await app.fetch(
      new Request("https://api.example.com/v1/apple/notifications", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          signedPayload: "valid.notification.jwt"
        })
      }),
      { ...defaultEnv, APPLE_BUNDLE_ID: "com.tshot.app" }
    );

    expect(response.status).toBe(200);
    expect(subscriptionWrites).toHaveLength(0);
  });

  it("acknowledges Apple notifications even when subscription persistence fails", async () => {
    const app = createApp(
      repository(user(), {
        subscriptionWriteError: new Error("supabase rejected subscription update")
      })
    );

    const response = await app.fetch(
      new Request("https://api.example.com/v1/apple/notifications", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          signedPayload: "valid.notification.jwt"
        })
      }),
      { ...defaultEnv, APPLE_BUNDLE_ID: "com.tshot.app" }
    );

    expect(response.status).toBe(200);
  });

  /**
   * 测试：中国大陆用户（CHN）应被拒绝访问 AI 功能
   * 地区检查应在订阅检查之前执行
   */
  it("rejects AI requests for China mainland users before subscription checks", async () => {
    const app = createApp(repository(user({ storefront: "CHN", countryCode: "CN", subscriptionStatus: "active" })));

    const response = await app.fetch(
      new Request("https://api.example.com/v1/ai/analyze-screenshot", {
        method: "POST",
        headers: {
          Authorization: "Bearer test-token",
          "Content-Type": "application/json"
        },
        body: JSON.stringify({ request_id: "req_1", image_base64: "aGVsbG8=" })
      }),
      defaultEnv
    );

    expect(response.status).toBe(403);
    await expect(json(response)).resolves.toMatchObject({
      error: "region_unavailable"
    });
  });

  /**
   * 测试：未知地区（storefront 为 null）应被保守拒绝
   */
  it("rejects AI requests for unknown storefronts conservatively", async () => {
    const app = createApp(repository(user({ storefront: null, subscriptionStatus: "active" })));

    const response = await app.fetch(
      new Request("https://api.example.com/v1/ai/analyze-screenshot", {
        method: "POST",
        headers: {
          Authorization: "Bearer test-token",
          "Content-Type": "application/json"
        },
        body: JSON.stringify({ request_id: "req_1", image_base64: "aGVsbG8=" })
      }),
      defaultEnv
    );

    expect(response.status).toBe(403);
    await expect(json(response)).resolves.toMatchObject({
      error: "region_unavailable"
    });
  });

  /**
   * 测试：未订阅的海外用户应被拒绝访问 AI 功能
   * 不应调用 AI 提供商
   */
  it("rejects unsubscribed overseas users without invoking AI", async () => {
    const app = createApp(repository(user({ storefront: "USA", subscriptionStatus: "inactive" })));

    const response = await app.fetch(
      new Request("https://api.example.com/v1/ai/analyze-screenshot", {
        method: "POST",
        headers: {
          Authorization: "Bearer test-token",
          "Content-Type": "application/json"
        },
        body: JSON.stringify({ request_id: "req_1", image_base64: "aGVsbG8=" })
      }),
      defaultEnv
    );

    expect(response.status).toBe(402);
    await expect(json(response)).resolves.toMatchObject({
      error: "subscription_required"
    });
  });

  /**
   * 测试：已认证的海外用户应能获取当前用量信息
   */
  it("returns current usage for authenticated overseas users", async () => {
    const app = createApp(repository(user({ storefront: "USA", monthlyUsedCount: 7, dailyUsedCount: 2 })));

    const response = await app.fetch(
      new Request("https://api.example.com/v1/usage/current", {
        headers: { Authorization: "Bearer test-token" }
      }),
      defaultEnv
    );

    expect(response.status).toBe(200);
    await expect(json(response)).resolves.toMatchObject({
      user_id: "user_1",
      monthly_used_count: 7,
      monthly_limit_count: 100,
      daily_used_count: 2,
      daily_limit_count: 20
    });
  });

  /**
   * 测试：已订阅的海外用户应能获取 AI 分析结果
   * 并正确记录可计费用量和更新配额
   */
  it("returns AI analysis and records billable usage for subscribed overseas users", async () => {
    const usageRecords: UsageRecordInput[] = [];
    const quotaIncrements: Array<{ userId: string; requestCount: number; tokenCount: number; cost: number }> = [];
    const calls: number[] = [];
    const app = createApp(
      repository(user({ storefront: "USA", subscriptionStatus: "active" }), { usageRecords, quotaIncrements }),
      aiProvider({ calls })
    );

    const response = await app.fetch(
      new Request("https://api.example.com/v1/ai/analyze-screenshot", {
        method: "POST",
        headers: {
          Authorization: "Bearer test-token",
          "Content-Type": "application/json"
        },
        body: JSON.stringify({
          request_id: "req_success",
          image_base64: "aGVsbG8=",
          prompt: "Explain this screenshot"
        })
      }),
      defaultEnv
    );

    expect(response.status).toBe(200);
    await expect(json(response)).resolves.toMatchObject({
      request_id: "req_success",
      analysis: "This screenshot shows a Swift build error and suggests checking the module import.",
      model: "gpt-5.4-mini"
    });
    expect(calls).toHaveLength(1);
    expect(usageRecords).toHaveLength(1);
    expect(usageRecords[0]).toMatchObject({
      userId: "user_1",
      requestId: "req_success",
      requestType: "analyze_screenshot",
      imageBytes: 5,
      billable: true,
      status: "succeeded",
      outputText: "This screenshot shows a Swift build error and suggests checking the module import."
    });
    expect(quotaIncrements).toEqual([
      { userId: "user_1", requestCount: 1, tokenCount: 104, cost: 0.00042 }
    ]);
  });

  /**
   * 测试：重复的请求 ID 应被拒绝（幂等性检查）
   * 不应再次调用 AI 提供商
   */
  it("rejects duplicate request IDs without invoking AI again", async () => {
    const calls: number[] = [];
    const app = createApp(
      repository(user({ storefront: "USA", subscriptionStatus: "active" }), { existingRequestId: "req_seen" }),
      aiProvider({ calls })
    );

    const response = await app.fetch(
      new Request("https://api.example.com/v1/ai/analyze-screenshot", {
        method: "POST",
        headers: {
          Authorization: "Bearer test-token",
          "Content-Type": "application/json"
        },
        body: JSON.stringify({ request_id: "req_seen", image_base64: "aGVsbG8=" })
      }),
      defaultEnv
    );

    expect(response.status).toBe(409);
    await expect(json(response)).resolves.toMatchObject({
      error: "duplicate_request"
    });
    expect(calls).toHaveLength(0);
  });

  /**
   * 测试：月度配额用尽时应被拒绝
   * 不应调用 AI 提供商
   */
  it("rejects monthly quota exhaustion before invoking AI", async () => {
    const calls: number[] = [];
    const app = createApp(
      repository(user({ storefront: "USA", subscriptionStatus: "active", monthlyUsedCount: 100 })),
      aiProvider({ calls })
    );

    const response = await app.fetch(
      new Request("https://api.example.com/v1/ai/analyze-screenshot", {
        method: "POST",
        headers: {
          Authorization: "Bearer test-token",
          "Content-Type": "application/json"
        },
        body: JSON.stringify({ request_id: "req_quota", image_base64: "aGVsbG8=" })
      }),
      defaultEnv
    );

    expect(response.status).toBe(429);
    await expect(json(response)).resolves.toMatchObject({
      error: "monthly_quota_exceeded"
    });
    expect(calls).toHaveLength(0);
  });

  /**
   * 测试：AI 提供商失败时应记录不可计费的失败请求
   * 不应更新配额
   */
  it("records a non-billable failure when AI provider fails", async () => {
    const usageRecords: UsageRecordInput[] = [];
    const quotaIncrements: Array<{ userId: string; requestCount: number; tokenCount: number; cost: number }> = [];
    const app = createApp(
      repository(user({ storefront: "USA", subscriptionStatus: "active" }), { usageRecords, quotaIncrements }),
      aiProvider({ error: new Error("provider down") })
    );

    const response = await app.fetch(
      new Request("https://api.example.com/v1/ai/analyze-screenshot", {
        method: "POST",
        headers: {
          Authorization: "Bearer test-token",
          "Content-Type": "application/json"
        },
        body: JSON.stringify({ request_id: "req_failed", image_base64: "aGVsbG8=" })
      }),
      defaultEnv
    );

    expect(response.status).toBe(502);
    await expect(json(response)).resolves.toMatchObject({
      error: "ai_provider_failed"
    });
    expect(usageRecords).toHaveLength(1);
    expect(usageRecords[0]).toMatchObject({
      requestId: "req_failed",
      billable: false,
      status: "failed"
    });
    expect(quotaIncrements).toHaveLength(0);
  });

  /**
   * 测试：AI 提供商不支持图片输入时应返回明确错误
   * 不应更新配额
   */
  it("returns unsupported input when AI provider cannot analyze images", async () => {
    const usageRecords: UsageRecordInput[] = [];
    const quotaIncrements: Array<{ userId: string; requestCount: number; tokenCount: number; cost: number }> = [];
    const error = Object.assign(new Error("DeepSeek does not support image input for screenshot analysis."), {
      code: "ai_provider_input_unsupported"
    });
    const app = createApp(
      repository(user({ storefront: "USA", subscriptionStatus: "active" }), { usageRecords, quotaIncrements }),
      aiProvider({ error })
    );

    const response = await app.fetch(
      new Request("https://api.example.com/v1/ai/analyze-screenshot", {
        method: "POST",
        headers: {
          Authorization: "Bearer test-token",
          "Content-Type": "application/json"
        },
        body: JSON.stringify({ request_id: "req_unsupported", image_base64: "aGVsbG8=" })
      }),
      defaultEnv
    );

    expect(response.status).toBe(422);
    await expect(json(response)).resolves.toMatchObject({
      error: "ai_provider_input_unsupported"
    });
    expect(usageRecords).toHaveLength(1);
    expect(usageRecords[0]).toMatchObject({
      requestId: "req_unsupported",
      billable: false,
      status: "failed"
    });
    expect(quotaIncrements).toHaveLength(0);
  });

  /**
   * 测试：没有 Authorization 头的文字分析请求应被拒绝
   */
  it("rejects text analysis requests without Authorization", async () => {
    const app = createApp(repository(user()));

    const response = await app.fetch(
      new Request("https://api.example.com/v1/ai/analyze-text", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ request_id: "text_req_1", prompt: "Hello" })
      }),
      defaultEnv
    );

    expect(response.status).toBe(401);
    await expect(json(response)).resolves.toMatchObject({
      error: "unauthorized"
    });
  });

  /**
   * 测试：中国大陆用户的文字分析请求应被拒绝
   */
  it("rejects text analysis requests for China mainland users", async () => {
    const app = createApp(repository(user({ storefront: "CHN", countryCode: "CN", subscriptionStatus: "active" })));

    const response = await app.fetch(
      new Request("https://api.example.com/v1/ai/analyze-text", {
        method: "POST",
        headers: {
          Authorization: "Bearer test-token",
          "Content-Type": "application/json"
        },
        body: JSON.stringify({ request_id: "text_req_1", prompt: "Hello" })
      }),
      defaultEnv
    );

    expect(response.status).toBe(403);
    await expect(json(response)).resolves.toMatchObject({
      error: "region_unavailable"
    });
  });

  /**
   * 测试：未订阅用户的文字分析请求应被拒绝
   * 不应调用 AI 提供商
   */
  it("rejects text analysis for unsubscribed users without invoking AI", async () => {
    const calls: number[] = [];
    const app = createApp(
      repository(user({ storefront: "USA", subscriptionStatus: "inactive" })),
      aiProvider({ calls })
    );

    const response = await app.fetch(
      new Request("https://api.example.com/v1/ai/analyze-text", {
        method: "POST",
        headers: {
          Authorization: "Bearer test-token",
          "Content-Type": "application/json"
        },
        body: JSON.stringify({ request_id: "text_req_1", prompt: "Hello" })
      }),
      defaultEnv
    );

    expect(response.status).toBe(402);
    await expect(json(response)).resolves.toMatchObject({
      error: "subscription_required"
    });
    expect(calls).toHaveLength(0);
  });

  /**
   * 测试：月度配额用尽时文字分析请求应被拒绝
   */
  it("rejects text analysis when monthly quota is exhausted", async () => {
    const calls: number[] = [];
    const app = createApp(
      repository(user({ storefront: "USA", subscriptionStatus: "active", monthlyUsedCount: 100 })),
      aiProvider({ calls })
    );

    const response = await app.fetch(
      new Request("https://api.example.com/v1/ai/analyze-text", {
        method: "POST",
        headers: {
          Authorization: "Bearer test-token",
          "Content-Type": "application/json"
        },
        body: JSON.stringify({ request_id: "text_req_1", prompt: "Hello" })
      }),
      defaultEnv
    );

    expect(response.status).toBe(429);
    await expect(json(response)).resolves.toMatchObject({
      error: "monthly_quota_exceeded"
    });
    expect(calls).toHaveLength(0);
  });

  /**
   * 测试：重复的 request_id 的文字分析请求应被拒绝
   */
  it("rejects duplicate text analysis requests", async () => {
    const calls: number[] = [];
    const app = createApp(
      repository(user({ storefront: "USA", subscriptionStatus: "active" }), { existingRequestId: "dup_req" }),
      aiProvider({ calls })
    );

    const response = await app.fetch(
      new Request("https://api.example.com/v1/ai/analyze-text", {
        method: "POST",
        headers: {
          Authorization: "Bearer test-token",
          "Content-Type": "application/json"
        },
        body: JSON.stringify({ request_id: "dup_req", prompt: "Hello" })
      }),
      defaultEnv
    );

    expect(response.status).toBe(409);
    await expect(json(response)).resolves.toMatchObject({
      error: "duplicate_request"
    });
    expect(calls).toHaveLength(0);
  });

  /**
   * 测试：已订阅的海外用户应能获取文字分析结果
   * 并正确记录可计费用量和更新配额
   */
  it("returns text analysis and records billable usage for subscribed overseas users", async () => {
    const usageRecords: UsageRecordInput[] = [];
    const quotaIncrements: Array<{ userId: string; requestCount: number; tokenCount: number; cost: number }> = [];
    const calls: number[] = [];
    const app = createApp(
      repository(user({ storefront: "USA", subscriptionStatus: "active" }), { usageRecords, quotaIncrements }),
      aiProvider({ calls })
    );

    const response = await app.fetch(
      new Request("https://api.example.com/v1/ai/analyze-text", {
        method: "POST",
        headers: {
          Authorization: "Bearer test-token",
          "Content-Type": "application/json"
        },
        body: JSON.stringify({
          request_id: "text_req_success",
          prompt: "请用中文解释什么是 REST API"
        })
      }),
      defaultEnv
    );

    expect(response.status).toBe(200);
    await expect(json(response)).resolves.toMatchObject({
      request_id: "text_req_success",
      analysis: "REST API 是一种基于 HTTP 协议的架构风格，用于构建 Web 服务。",
      model: "gpt-5.4-mini"
    });
    expect(calls).toHaveLength(1);
    expect(usageRecords).toHaveLength(1);
    expect(usageRecords[0]).toMatchObject({
      userId: "user_1",
      requestId: "text_req_success",
      requestType: "analyze_text",
      imageBytes: 0,
      imageCount: 0,
      billable: true,
      status: "succeeded",
      outputText: "REST API 是一种基于 HTTP 协议的架构风格，用于构建 Web 服务。"
    });
    expect(quotaIncrements).toEqual([
      { userId: "user_1", requestCount: 1, tokenCount: 95, cost: 0.00015 }
    ]);
  });

  /**
   * 测试：AI 提供商失败时文字分析应记录不可计费的失败请求
   */
  it("records non-billable failure when AI provider fails for text analysis", async () => {
    const usageRecords: UsageRecordInput[] = [];
    const quotaIncrements: Array<{ userId: string; requestCount: number; tokenCount: number; cost: number }> = [];
    const app = createApp(
      repository(user({ storefront: "USA", subscriptionStatus: "active" }), { usageRecords, quotaIncrements }),
      aiProvider({ error: new Error("provider down") })
    );

    const response = await app.fetch(
      new Request("https://api.example.com/v1/ai/analyze-text", {
        method: "POST",
        headers: {
          Authorization: "Bearer test-token",
          "Content-Type": "application/json"
        },
        body: JSON.stringify({ request_id: "text_req_fail", prompt: "Hello" })
      }),
      defaultEnv
    );

    expect(response.status).toBe(502);
    await expect(json(response)).resolves.toMatchObject({
      error: "ai_provider_failed"
    });
    expect(usageRecords).toHaveLength(1);
    expect(usageRecords[0]).toMatchObject({
      requestId: "text_req_fail",
      requestType: "analyze_text",
      imageBytes: 0,
      imageCount: 0,
      billable: false,
      status: "failed"
    });
    expect(quotaIncrements).toHaveLength(0);
  });

  /**
   * 测试：缺少 request_id 的文字分析请求应被拒绝
   */
  it("rejects text analysis requests without request_id", async () => {
    const app = createApp(repository(user({ storefront: "USA", subscriptionStatus: "active" })));

    const response = await app.fetch(
      new Request("https://api.example.com/v1/ai/analyze-text", {
        method: "POST",
        headers: {
          Authorization: "Bearer test-token",
          "Content-Type": "application/json"
        },
        body: JSON.stringify({ prompt: "Hello" })
      }),
      defaultEnv
    );

    expect(response.status).toBe(400);
    await expect(json(response)).resolves.toMatchObject({
      error: "invalid_request"
    });
  });
});
