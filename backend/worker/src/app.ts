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

export type UsageRecordStatus = "accepted" | "blocked" | "succeeded" | "failed";

export interface UsageRecordSnapshot {
  requestId: string;
  status: UsageRecordStatus;
}

export interface UsageRecordInput {
  userId: string;
  requestId: string;
  requestType: "analyze_screenshot";
  model: string | null;
  imageBytes: number;
  imageCount: number;
  inputTokenCount: number;
  outputTokenCount: number;
  estimatedCost: number;
  billable: boolean;
  status: UsageRecordStatus;
  outputText?: string;
}

export interface SubscriptionSnapshot {
  userId: string;
  status: SubscriptionStatus;
  productId: string | null;
  expiresAt?: string | null;
}

export interface BackendRepository {
  findUserByBearerToken(token: string): Promise<UserProfile | null>;
  findUsageRecordByRequestId(userId: string, requestId: string): Promise<UsageRecordSnapshot | null>;
  getUsage(userId: string): Promise<UsageSnapshot>;
  getSubscriptionStatus(userId: string): Promise<SubscriptionSnapshot>;
  recordUsage(record: UsageRecordInput): Promise<void>;
  incrementMonthlyQuota(userId: string, requestCount: number, tokenCount: number, cost: number): Promise<void>;
}

export interface BackendEnv {
  ALLOWED_STOREFRONTS: string;
  MONTHLY_REQUEST_LIMIT: string;
  DAILY_REQUEST_LIMIT: string;
  MAX_IMAGE_BYTES: string;
  AI_MODEL: string;
  AI_MAX_OUTPUT_TOKENS: string;
}

export interface AIProviderRequest {
  requestId: string;
  userId: string;
  imageBase64: string;
  prompt: string;
  model: string;
  maxOutputTokens: number;
}

export interface AIProviderResult {
  text: string;
  model: string;
  inputTokenCount: number;
  outputTokenCount: number;
  estimatedCost: number;
}

export interface AIProvider {
  analyzeScreenshot(request: AIProviderRequest): Promise<AIProviderResult>;
}

export interface BackendApp {
  fetch(request: Request, env: BackendEnv): Promise<Response>;
}

interface RequestContext {
  request: Request;
  env: BackendEnv;
  repository: BackendRepository;
  aiProvider: AIProvider;
}

type Handler = (context: RequestContext) => Promise<Response>;

interface AuthenticatedContext extends RequestContext {
  user: UserProfile;
}

const jsonHeaders = {
  "Content-Type": "application/json; charset=utf-8"
};

export function createApp(repository: BackendRepository, aiProvider: AIProvider = unavailableAIProvider): BackendApp {
  return {
    async fetch(request, env) {
      return handleRequest({ request, env, repository, aiProvider });
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

  const requestId = body.request_id.trim();
  if (!requestId) {
    return json({ error: "invalid_request" }, 400);
  }

  const existingRecord = await context.repository.findUsageRecordByRequestId(context.user.id, requestId);
  if (existingRecord) {
    return json({ error: "duplicate_request", status: existingRecord.status }, 409);
  }

  const imageBytes = estimateBase64Bytes(body.image_base64);
  if (imageBytes > numberFromEnv(context.env.MAX_IMAGE_BYTES, 2_097_152)) {
    return json({ error: "image_too_large" }, 413);
  }

  const model = context.env.AI_MODEL || "gpt-5.4-mini";
  const prompt = typeof body.prompt === "string" && body.prompt.trim()
    ? body.prompt.trim()
    : "Analyze this screenshot. Explain the likely context, key text, and actionable next steps.";

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
    return json({ error: "ai_provider_failed" }, 502);
  }

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

const unavailableAIProvider: AIProvider = {
  async analyzeScreenshot() {
    throw new Error("AI provider is not configured");
  }
};
