import { describe, expect, it } from "vitest";
import { createApp, type BackendEnv, type BackendRepository, type UserProfile } from "../src/app";

const defaultEnv: BackendEnv = {
  ALLOWED_STOREFRONTS: "USA,JPN",
  MONTHLY_REQUEST_LIMIT: "100",
  DAILY_REQUEST_LIMIT: "20",
  MAX_IMAGE_BYTES: "2097152"
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

function repository(profile: UserProfile | null): BackendRepository {
  return {
    async findUserByBearerToken() {
      return profile;
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
});
