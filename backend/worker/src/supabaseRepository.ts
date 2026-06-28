import type {
  BackendRepository,
  SubscriptionSnapshot,
  SubscriptionStatus,
  UsageSnapshot,
  UserProfile
} from "./app";

export interface SupabaseEnv {
  SUPABASE_URL: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
}

interface SupabaseUserRow {
  id: string;
  country_code: string | null;
  storefront: string | null;
  subscription_status: SubscriptionStatus | null;
  monthly_used_count: number | null;
  daily_used_count: number | null;
}

interface SupabaseSubscriptionRow {
  user_id: string;
  product_id: string | null;
  status: SubscriptionStatus;
  expires_at: string | null;
}

interface SupabaseUsageRow {
  user_id: string;
  monthly_used_count: number | null;
  monthly_limit_count: number | null;
  daily_used_count: number | null;
  daily_limit_count: number | null;
}

export class SupabaseRepository implements BackendRepository {
  constructor(private readonly env: SupabaseEnv) {}

  async findUserByBearerToken(token: string): Promise<UserProfile | null> {
    const tokenHash = await sha256Hex(token);
    const rows = await this.query<SupabaseUserRow>("user_ai_access", {
      token_hash: `eq.${tokenHash}`,
      limit: "1"
    });

    const row = rows[0];
    if (!row) {
      return null;
    }

    return {
      id: row.id,
      countryCode: row.country_code,
      storefront: row.storefront,
      subscriptionStatus: row.subscription_status ?? "inactive",
      monthlyUsedCount: row.monthly_used_count ?? 0,
      dailyUsedCount: row.daily_used_count ?? 0
    };
  }

  async getUsage(userId: string): Promise<UsageSnapshot> {
    const rows = await this.query<SupabaseUsageRow>("usage_current", {
      user_id: `eq.${userId}`,
      limit: "1"
    });
    const row = rows[0];

    return {
      userId,
      monthlyUsedCount: row?.monthly_used_count ?? 0,
      monthlyLimitCount: row?.monthly_limit_count ?? 100,
      dailyUsedCount: row?.daily_used_count ?? 0,
      dailyLimitCount: row?.daily_limit_count ?? 20
    };
  }

  async getSubscriptionStatus(userId: string): Promise<SubscriptionSnapshot> {
    const rows = await this.query<SupabaseSubscriptionRow>("subscriptions", {
      user_id: `eq.${userId}`,
      order: "updated_at.desc",
      limit: "1"
    });
    const row = rows[0];

    return {
      userId,
      status: row?.status ?? "inactive",
      productId: row?.product_id ?? null,
      expiresAt: row?.expires_at ?? null
    };
  }

  private async query<T>(table: string, params: Record<string, string>): Promise<T[]> {
    const url = new URL(`/rest/v1/${table}`, this.env.SUPABASE_URL);
    for (const [key, value] of Object.entries(params)) {
      url.searchParams.set(key, value);
    }

    const response = await fetch(url, {
      headers: {
        apikey: this.env.SUPABASE_SERVICE_ROLE_KEY,
        Authorization: `Bearer ${this.env.SUPABASE_SERVICE_ROLE_KEY}`,
        Accept: "application/json"
      }
    });

    if (!response.ok) {
      throw new Error(`Supabase query failed: ${response.status}`);
    }

    return (await response.json()) as T[];
  }
}

async function sha256Hex(value: string): Promise<string> {
  const data = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}
