export type SubscriptionStatus = "active" | "inactive" | "expired" | "refunded" | "grace_period";

export interface UserProfile {
  id: string;
  storefront: string | null;
  countryCode: string | null;
  subscriptionStatus: SubscriptionStatus;
  monthlyUsedCount: number;
  dailyUsedCount: number;
}

export interface UsageSnapshot {
  userId: string;
  monthlyUsedCount: number;
  monthlyLimitCount: number;
  dailyUsedCount: number;
  dailyLimitCount: number;
}

export interface SubscriptionSnapshot {
  userId: string;
  status: SubscriptionStatus;
  productId: string | null;
  expiresAt?: string | null;
}

export interface BackendRepository {
  findUserByBearerToken(token: string): Promise<UserProfile | null>;
  getUsage(userId: string): Promise<UsageSnapshot>;
  getSubscriptionStatus(userId: string): Promise<SubscriptionSnapshot>;
}

export interface BackendEnv {
  ALLOWED_STOREFRONTS: string;
  MONTHLY_REQUEST_LIMIT: string;
  DAILY_REQUEST_LIMIT: string;
  MAX_IMAGE_BYTES: string;
}

export interface BackendApp {
  fetch(request: Request, env: BackendEnv): Promise<Response>;
}

interface RequestContext {
  request: Request;
  env: BackendEnv;
  repository: BackendRepository;
}

type Handler = (context: RequestContext) => Promise<Response>;

interface AuthenticatedContext extends RequestContext {
  user: UserProfile;
}

const jsonHeaders = {
  "Content-Type": "application/json; charset=utf-8"
};

export function createApp(repository: BackendRepository): BackendApp {
  return {
    async fetch(request, env) {
      return handleRequest({ request, env, repository });
    }
  };
}

async function handleRequest(context: RequestContext): Promise<Response> {
  const url = new URL(context.request.url);
  const routeKey = `${context.request.method} ${url.pathname}`;
  const routes: Record<string, Handler> = {
    "GET /health": async () => json({ status: "ok" }),
    "POST /v1/auth/apple": notImplemented("auth_not_implemented"),
    "POST /v1/subscriptions/verify": notImplemented("subscription_verify_not_implemented"),
    "GET /v1/subscriptions/status": withAuthenticatedUser(handleSubscriptionStatus),
    "GET /v1/usage/current": withAuthenticatedUser(handleUsageCurrent),
    "POST /v1/ai/analyze-screenshot": withAuthenticatedUser(handleAnalyzeScreenshot),
    "POST /v1/apple/notifications": async () => json({ accepted: true }, 202)
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

function notImplemented(error: string): Handler {
  return async () => json({ error }, 501);
}

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

async function handleAnalyzeScreenshot(context: AuthenticatedContext): Promise<Response> {
  const regionError = validateRegion(context.user, context.env);
  if (regionError) {
    return regionError;
  }

  if (context.user.subscriptionStatus !== "active" && context.user.subscriptionStatus !== "grace_period") {
    return json({ error: "subscription_required" }, 402);
  }

  const quotaError = validateQuota(context.user, context.env);
  if (quotaError) {
    return quotaError;
  }

  const body = await parseJsonBody(context.request);
  if (!body || typeof body.request_id !== "string" || typeof body.image_base64 !== "string") {
    return json({ error: "invalid_request" }, 400);
  }

  const imageBytes = estimateBase64Bytes(body.image_base64);
  if (imageBytes > numberFromEnv(context.env.MAX_IMAGE_BYTES, 2_097_152)) {
    return json({ error: "image_too_large" }, 413);
  }

  return json({ error: "ai_forwarding_not_implemented" }, 501);
}

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

function bearerToken(request: Request): string | null {
  const authorization = request.headers.get("Authorization");
  const match = authorization?.match(/^Bearer\s+(.+)$/i);
  return match?.[1]?.trim() || null;
}

async function parseJsonBody(request: Request): Promise<Record<string, unknown> | null> {
  try {
    return (await request.json()) as Record<string, unknown>;
  } catch {
    return null;
  }
}

function estimateBase64Bytes(value: string): number {
  const normalized = value.replace(/^data:[^,]+,/, "").replace(/\s/g, "");
  const padding = normalized.endsWith("==") ? 2 : normalized.endsWith("=") ? 1 : 0;
  return Math.max(0, Math.floor((normalized.length * 3) / 4) - padding);
}

function numberFromEnv(value: string, fallback: number): number {
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: jsonHeaders
  });
}
