/**
 * Supabase 数据库访问层实现
 * 使用 Supabase REST API 进行数据读写操作
 */

import type {
  BackendRepository,
  SubscriptionSnapshot,
  SubscriptionStatus,
  UsageRecordInput,
  UsageRecordSnapshot,
  UsageSnapshot,
  UserProfile
} from "./app";

/**
 * Supabase 环境变量接口
 */
export interface SupabaseEnv {
  /** Supabase 项目 URL */
  SUPABASE_URL: string;
  /** Supabase Service Role 密钥（具有完全数据库访问权限） */
  SUPABASE_SERVICE_ROLE_KEY: string;
}

/**
 * Supabase user_ai_access 表行结构
 */
interface SupabaseUserRow {
  /** 用户唯一标识符 */
  id: string;
  /** 国家代码 */
  country_code: string | null;
  /** App Store 地区代码 */
  storefront: string | null;
  /** 订阅状态 */
  subscription_status: SubscriptionStatus | null;
  /** 当月已使用次数 */
  monthly_used_count: number | null;
  /** 当日已使用次数 */
  daily_used_count: number | null;
}

/**
 * Supabase subscriptions 表行结构
 */
interface SupabaseSubscriptionRow {
  /** 用户唯一标识符 */
  user_id: string;
  /** 产品 ID */
  product_id: string | null;
  /** 订阅状态 */
  status: SubscriptionStatus;
  /** 过期时间 */
  expires_at: string | null;
}

/**
 * Supabase usage_current 表行结构
 */
interface SupabaseUsageRow {
  /** 用户唯一标识符 */
  user_id: string;
  /** 当月已使用次数 */
  monthly_used_count: number | null;
  /** 当月配额上限 */
  monthly_limit_count: number | null;
  /** 当日已使用次数 */
  daily_used_count: number | null;
  /** 当日配额上限 */
  daily_limit_count: number | null;
}

/**
 * Supabase usage_records 表行结构（简化版）
 */
interface SupabaseUsageRecordRow {
  /** 请求唯一标识符 */
  request_id: string;
  /** 请求状态 */
  status: UsageRecordSnapshot["status"];
}

/**
 * Supabase 数据访问层类
 * 实现 BackendRepository 接口，提供用户、订阅和用量数据的 CRUD 操作
 */
export class SupabaseRepository implements BackendRepository {
  /**
   * 构造函数
   * @param env Supabase 环境变量配置
   */
  constructor(private readonly env: SupabaseEnv) {}

  /**
   * 通过 Bearer Token 查找用户
   * Token 会先进行 SHA-256 哈希处理，然后在 user_ai_access 表中查找
   * @param token 用户认证令牌
   * @returns 用户档案，未找到时返回 null
   */
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

  /**
   * 获取用户当前用量
   * @param userId 用户唯一标识符
   * @returns 用量快照
   */
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

  /**
   * 通过请求 ID 查找用量记录
   * 用于幂等性检查，防止重复请求
   * @param userId 用户唯一标识符
   * @param requestId 请求唯一标识符
   * @returns 用量记录快照，未找到时返回 null
   */
  async findUsageRecordByRequestId(userId: string, requestId: string): Promise<UsageRecordSnapshot | null> {
    const rows = await this.query<SupabaseUsageRecordRow>("usage_records", {
      user_id: `eq.${userId}`,
      request_id: `eq.${requestId}`,
      select: "request_id,status",
      limit: "1"
    });
    const row = rows[0];
    if (!row) {
      return null;
    }

    return {
      requestId: row.request_id,
      status: row.status
    };
  }

  /**
   * 获取用户订阅状态
   * 查询最新的订阅记录（按 updated_at 降序）
   * @param userId 用户唯一标识符
   * @returns 订阅快照
   */
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

  /**
   * 记录用量
   * 向 usage_records 表插入一条新记录
   * @param record 用量记录输入
   */
  async recordUsage(record: UsageRecordInput): Promise<void> {
    await this.insert("usage_records", {
      user_id: record.userId,
      request_id: record.requestId,
      request_type: record.requestType,
      model: record.model,
      image_bytes: record.imageBytes,
      image_count: record.imageCount,
      input_token_count: record.inputTokenCount,
      output_token_count: record.outputTokenCount,
      estimated_cost: record.estimatedCost,
      billable: record.billable,
      status: record.status,
      output_text: record.outputText ?? null
    });
  }

  /**
   * 增加月度配额消耗
   * 调用 Supabase RPC 函数 increment_monthly_quota 更新配额
   * @param userId 用户唯一标识符
   * @param requestCount 请求次数增量
   * @param tokenCount Token 数量增量
   * @param cost 预估费用增量
   */
  async incrementMonthlyQuota(userId: string, requestCount: number, tokenCount: number, cost: number): Promise<void> {
    const response = await fetch(new URL("/rest/v1/rpc/increment_monthly_quota", this.env.SUPABASE_URL), {
      method: "POST",
      headers: this.headers({ "Content-Type": "application/json" }),
      body: JSON.stringify({
        p_user_id: userId,
        p_request_count: requestCount,
        p_token_count: tokenCount,
        p_cost: cost
      })
    });

    if (!response.ok) {
      throw new Error(`Supabase quota increment failed: ${response.status}`);
    }
  }

  /**
   * 执行 Supabase REST API 查询
   * @param table 表名
   * @param params 查询参数（转换为 URL 查询字符串）
   * @returns 查询结果数组
   */
  private async query<T>(table: string, params: Record<string, string>): Promise<T[]> {
    const url = new URL(`/rest/v1/${table}`, this.env.SUPABASE_URL);
    for (const [key, value] of Object.entries(params)) {
      url.searchParams.set(key, value);
    }

    const response = await fetch(url, { headers: this.headers() });

    if (!response.ok) {
      throw new Error(`Supabase query failed: ${response.status}`);
    }

    return (await response.json()) as T[];
  }

  /**
   * 执行 Supabase REST API 插入操作
   * @param table 表名
   * @param body 插入数据
   */
  private async insert(table: string, body: Record<string, unknown>): Promise<void> {
    const response = await fetch(new URL(`/rest/v1/${table}`, this.env.SUPABASE_URL), {
      method: "POST",
      headers: this.headers({
        "Content-Type": "application/json",
        Prefer: "return=minimal"
      }),
      body: JSON.stringify(body)
    });

    if (!response.ok) {
      throw new Error(`Supabase insert failed: ${response.status}`);
    }
  }

  /**
   * 构建 Supabase API 请求头
   * @param extra 额外的请求头（可选）
   * @returns 请求头对象
   */
  private headers(extra: Record<string, string> = {}): Record<string, string> {
    return {
      apikey: this.env.SUPABASE_SERVICE_ROLE_KEY,
      Authorization: `Bearer ${this.env.SUPABASE_SERVICE_ROLE_KEY}`,
      Accept: "application/json",
      ...extra
    };
  }
}

/**
 * 计算字符串的 SHA-256 哈希值（十六进制格式）
 * @param value 输入字符串
 * @returns SHA-256 哈希值（小写十六进制）
 */
async function sha256Hex(value: string): Promise<string> {
  const data = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}
