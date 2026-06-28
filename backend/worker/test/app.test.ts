import { describe, expect, it } from "vitest";
import {
  createApp,
  type AIProvider,
  type BackendEnv,
  type BackendRepository,
  type UsageRecordInput,
  type UserProfile
} from "../src/app";

const defaultEnv: BackendEnv = {
  ALLOWED_STOREFRONTS: "USA,JPN",
  MONTHLY_REQUEST_LIMIT: "100",
  DAILY_REQUEST_LIMIT: "20",
  MAX_IMAGE_BYTES: "2097152",
  AI_MODEL: "gpt-5.4-mini",
  AI_MAX_OUTPUT_TOKENS: "1200"
};

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

function repository(profile: UserProfile | null, options: {
  existingRequestId?: string;
  usageRecords?: UsageRecordInput[];
  quotaIncrements?: Array<{ userId: string; requestCount: number; tokenCount: number; cost: number }>;
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
    }
  };
}

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
    }
  };
}

async function json(response: Response) {
  return response.json() as Promise<Record<string, unknown>>;
}

describe("TShot AI backend app", () => {
  it("rejects usage requests without Authorization", async () => {
    const app = createApp(repository(user()));

    const response = await app.fetch(new Request("https://api.example.com/v1/usage/current"), defaultEnv);

    expect(response.status).toBe(401);
    await expect(json(response)).resolves.toMatchObject({
      error: "unauthorized"
    });
  });

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
});
