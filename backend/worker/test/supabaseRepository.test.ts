import { afterEach, describe, expect, it, vi } from "vitest";
import { SupabaseRepository } from "../src/supabaseRepository";

describe("SupabaseRepository", () => {
  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it("rebinds an existing original transaction to the current signed-in user when restoring a subscription", async () => {
    const requests: Array<{ url: string; init: RequestInit | undefined }> = [];
    vi.stubGlobal(
      "fetch",
      vi.fn(async (url: URL | string, init?: RequestInit) => {
        requests.push({ url: String(url), init });

        if (String(url).includes("/rest/v1/subscriptions?")) {
          return Response.json([{ id: 42 }]);
        }

        return new Response(null, { status: 204 });
      })
    );

    const repository = new SupabaseRepository({
      SUPABASE_URL: "https://example.supabase.co",
      SUPABASE_SERVICE_ROLE_KEY: "service-role-key"
    });

    await repository.createOrUpdateSubscription("current-user-id", {
      originalTransactionId: "original-transaction-id",
      latestTransactionId: "latest-transaction-id",
      productId: "tshot.pro.monthly",
      environment: "Sandbox",
      expiresAt: new Date(Date.now() + 86_400_000).toISOString()
    });

    const updateRequest = requests.find((request) => request.init?.method === "PATCH");
    expect(updateRequest).toBeDefined();
    expect(JSON.parse(updateRequest!.init!.body as string)).toMatchObject({
      user_id: "current-user-id",
      product_id: "tshot.pro.monthly",
      latest_transaction_id: "latest-transaction-id",
      environment: "Sandbox",
      status: "active"
    });
  });

  it("uses the App Store notification status when updating a subscription", async () => {
    const requests: Array<{ url: string; init: RequestInit | undefined }> = [];
    vi.stubGlobal(
      "fetch",
      vi.fn(async (url: URL | string, init?: RequestInit) => {
        requests.push({ url: String(url), init });

        if (String(url).includes("/rest/v1/subscriptions?")) {
          return Response.json([{ id: 42 }]);
        }

        return new Response(null, { status: 204 });
      })
    );

    const repository = new SupabaseRepository({
      SUPABASE_URL: "https://example.supabase.co",
      SUPABASE_SERVICE_ROLE_KEY: "service-role-key"
    });

    await repository.createOrUpdateSubscription("current-user-id", {
      originalTransactionId: "original-transaction-id",
      latestTransactionId: "latest-transaction-id",
      productId: "tshot.pro.monthly",
      environment: "Sandbox",
      expiresAt: new Date(Date.now() + 86_400_000).toISOString(),
      status: "refunded"
    });

    const updateRequest = requests.find((request) => request.init?.method === "PATCH");
    expect(updateRequest).toBeDefined();
    expect(JSON.parse(updateRequest!.init!.body as string)).toMatchObject({
      status: "refunded"
    });
  });

  it("inserts local StoreKit subscription restores for development verification", async () => {
    const requests: Array<{ url: string; init: RequestInit | undefined }> = [];
    vi.stubGlobal(
      "fetch",
      vi.fn(async (url: URL | string, init?: RequestInit) => {
        requests.push({ url: String(url), init });

        if (String(url).includes("/rest/v1/subscriptions?")) {
          return Response.json([]);
        }

        return new Response(null, { status: 204 });
      })
    );

    const repository = new SupabaseRepository({
      SUPABASE_URL: "https://example.supabase.co",
      SUPABASE_SERVICE_ROLE_KEY: "service-role-key"
    });

    await repository.createOrUpdateSubscription("current-user-id", {
      originalTransactionId: "local-original-transaction-id",
      latestTransactionId: "local-latest-transaction-id",
      productId: "tshot.pro.monthly",
      environment: "Xcode",
      expiresAt: new Date(Date.now() + 86_400_000).toISOString()
    });

    const insertRequest = requests.find((request) => request.init?.method === "POST");
    expect(insertRequest).toBeDefined();
    expect(JSON.parse(insertRequest!.init!.body as string)).toMatchObject({
      user_id: "current-user-id",
      product_id: "tshot.pro.monthly",
      original_transaction_id: "local-original-transaction-id",
      latest_transaction_id: "local-latest-transaction-id",
      environment: "Xcode",
      status: "active"
    });
  });
});
