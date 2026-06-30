-- =============================================
-- AI Backend MVP 数据库初始化脚本
-- 创建时间: 2026-06-28
-- 描述: AI Pro 功能的核心数据库表结构
-- 包含: 用户认证、订阅管理、用量记录、配额管理、滥用检测
-- =============================================

-- 启用 pgcrypto 扩展，用于生成 UUID 和加密操作
create extension if not exists pgcrypto;

-- =============================================
-- 用户表
-- 存储 Apple 登录用户的基本信息
-- =============================================
create table if not exists public.users (
  id uuid primary key default gen_random_uuid(),  -- 用户唯一标识
  apple_user_id text not null unique,             -- Apple 登录返回的用户 ID
  email text,                                     -- 用户邮箱（可选）
  display_name text,                              -- 用户显示名称（可选）
  country_code text,                              -- 用户所在国家代码
  storefront text,                                -- App Store 商店地区代码
  created_at timestamptz not null default now(),  -- 创建时间
  updated_at timestamptz not null default now()   -- 更新时间
);

-- =============================================
-- 应用会话表
-- 存储用户登录后的会话信息，用于 API 鉴权
-- =============================================
create table if not exists public.app_sessions (
  id bigint generated always as identity primary key,  -- 会话自增 ID
  user_id uuid not null references public.users(id) on delete cascade,  -- 关联用户
  token_hash text not null unique,      -- 会话令牌的哈希值（用于验证）
  created_at timestamptz not null default now(),  -- 创建时间
  expires_at timestamptz,               -- 过期时间（可选）
  revoked_at timestamptz                -- 撤销时间（退出登录时设置）
);

-- =============================================
-- 订阅表
-- 存储用户的 App Store 订阅信息
-- =============================================
create table if not exists public.subscriptions (
  id bigint generated always as identity primary key,  -- 订阅自增 ID
  user_id uuid not null references public.users(id) on delete cascade,  -- 关联用户
  product_id text not null,             -- 订阅产品 ID（如 com.tytool.aipro.monthly）
  original_transaction_id text not null unique,  -- App Store 原始交易 ID
  latest_transaction_id text not null,  -- App Store 最新交易 ID
  status text not null,                 -- 订阅状态（见约束）
  expires_at timestamptz,               -- 订阅过期时间
  environment text not null,            -- 环境（Sandbox / Production）
  created_at timestamptz not null default now(),  -- 创建时间
  updated_at timestamptz not null default now(),  -- 更新时间
  -- 订阅状态约束：active(有效) / inactive(无效) / expired(已过期) / refunded(已退款) / grace_period(宽限期)
  constraint subscriptions_status_check check (
    status in ('active', 'inactive', 'expired', 'refunded', 'grace_period')
  ),
  -- 环境约束
  constraint subscriptions_environment_check check (
    environment in ('Sandbox', 'Production')
  )
);

-- =============================================
-- 用量记录表
-- 记录用户每次 AI 分析请求的详细信息
-- =============================================
create table if not exists public.usage_records (
  id bigint generated always as identity primary key,  -- 记录自增 ID
  user_id uuid not null references public.users(id) on delete cascade,  -- 关联用户
  request_id text not null,             -- 请求唯一标识（客户端生成）
  request_type text not null,           -- 请求类型（见约束）
  model text,                           -- 使用的 AI 模型名称
  image_bytes integer not null default 0,  -- 上传图片字节数
  image_count integer not null default 0,  -- 图片数量
  input_token_count integer not null default 0,  -- 输入 token 数
  output_token_count integer not null default 0,  -- 输出 token 数
  estimated_cost numeric(12, 6) not null default 0,  -- 估算费用（美元）
  billable boolean not null default false,  -- 是否计费
  status text not null,                 -- 请求状态（见约束）
  output_text text,                     -- AI 分析结果文本
  created_at timestamptz not null default now(),  -- 创建时间
  -- 请求类型约束：analyze_screenshot(截图分析)
  constraint usage_records_request_type_check check (
    request_type in ('analyze_screenshot')
  ),
  -- 请求状态约束：accepted(已接受) / blocked(被拦截) / succeeded(成功) / failed(失败)
  constraint usage_records_status_check check (
    status in ('accepted', 'blocked', 'succeeded', 'failed')
  ),
  -- 同一用户同一请求 ID 唯一
  constraint usage_records_request_id_unique unique (user_id, request_id)
);

-- =============================================
-- 月度配额表
-- 记录用户每月的 AI 服务使用配额
-- =============================================
create table if not exists public.monthly_quotas (
  id bigint generated always as identity primary key,  -- 配额自增 ID
  user_id uuid not null references public.users(id) on delete cascade,  -- 关联用户
  month date not null,                  -- 月份（YYYY-MM-DD，当月第一天）
  used_count integer not null default 0,  -- 已使用请求次数
  limit_count integer not null default 100,  -- 每月请求次数上限
  used_tokens integer not null default 0,  -- 已使用 token 数
  limit_tokens integer not null default 120000,  -- 每月 token 上限
  used_cost numeric(12, 6) not null default 0,  -- 已产生费用
  limit_cost numeric(12, 6) not null default 5,  -- 每月费用上限（美元）
  created_at timestamptz not null default now(),  -- 创建时间
  updated_at timestamptz not null default now(),  -- 更新时间
  -- 同一用户同一月份唯一
  constraint monthly_quotas_user_month_unique unique (user_id, month)
);

-- =============================================
-- 滥用事件表
-- 记录用户的异常行为，用于风控
-- =============================================
create table if not exists public.abuse_events (
  id bigint generated always as identity primary key,  -- 事件自增 ID
  user_id uuid references public.users(id) on delete set null,  -- 关联用户（可空）
  ip inet,                              -- 用户 IP 地址
  reason text not null,                 -- 触发原因
  detail jsonb,                         -- 详细信息（JSON 格式）
  created_at timestamptz not null default now()  -- 创建时间
);

-- =============================================
-- 索引定义
-- =============================================

-- 用户会话索引：加速按用户查询会话
create index if not exists app_sessions_user_id_idx on public.app_sessions(user_id);

-- 订阅索引：加速按用户查询订阅
create index if not exists subscriptions_user_id_idx on public.subscriptions(user_id);

-- 订阅状态+过期时间索引：加速查询即将过期的订阅
create index if not exists subscriptions_status_expires_at_idx on public.subscriptions(status, expires_at);

-- 用量记录索引：加速按用户和时间查询用量
create index if not exists usage_records_user_id_created_at_idx on public.usage_records(user_id, created_at desc);

-- 月度配额索引：加速按用户和月份查询配额
create index if not exists monthly_quotas_user_id_month_idx on public.monthly_quotas(user_id, month desc);

-- 滥用事件索引：加速按用户和时间查询事件
create index if not exists abuse_events_user_id_created_at_idx on public.abuse_events(user_id, created_at desc);

-- =============================================
-- 行级安全策略（RLS）
-- 启用所有表的 RLS，防止未授权访问
-- =============================================
alter table public.users enable row level security;
alter table public.app_sessions enable row level security;
alter table public.subscriptions enable row level security;
alter table public.usage_records enable row level security;
alter table public.monthly_quotas enable row level security;
alter table public.abuse_events enable row level security;

-- =============================================
-- service_role 权限授予
-- service_role 需要使用 service_role key 访问所有表（绕过 RLS）
-- Supabase 本地环境 auto_expose_new_tables 默认为 false，需要显式授权
-- =============================================
grant all on all tables in schema public to service_role;
grant all on all sequences in schema public to service_role;
grant execute on all functions in schema public to service_role;

-- =============================================
-- 视图：usage_current
-- 查询用户当前的使用情况（月度和每日）
-- =============================================
create or replace view public.usage_current as
select
  u.id as user_id,
  coalesce(mq.used_count, 0) as monthly_used_count,       -- 本月已用请求次数
  coalesce(mq.limit_count, 100) as monthly_limit_count,   -- 本月请求次数上限
  coalesce(today.daily_used_count, 0) as daily_used_count,  -- 今日已用请求次数
  20 as daily_limit_count                                   -- 每日请求次数上限（固定值）
from public.users u
left join public.monthly_quotas mq
  on mq.user_id = u.id
  and mq.month = date_trunc('month', now())::date  -- 匹配当前月份
left join lateral (
  -- 统计今日计费成功的请求数
  select count(*)::integer as daily_used_count
  from public.usage_records ur
  where ur.user_id = u.id
    and ur.billable = true
    and ur.status = 'succeeded'
    and ur.created_at >= date_trunc('day', now())
) today on true;

-- =============================================
-- 视图：user_ai_access
-- 查询用户的 AI 访问权限信息
-- 用于 API 鉴权时快速判断用户是否有权限使用 AI 功能
-- =============================================
create or replace view public.user_ai_access as
select
  s.token_hash,                          -- 会话令牌哈希（用于匹配）
  u.id,                                  -- 用户 ID
  u.country_code,                        -- 国家代码（用于地区限制）
  u.storefront,                          -- 商店地区（用于地区限制）
  coalesce(sub.status, 'inactive') as subscription_status,  -- 订阅状态
  coalesce(usage.monthly_used_count, 0) as monthly_used_count,  -- 本月已用次数
  coalesce(usage.daily_used_count, 0) as daily_used_count    -- 今日已用次数
from public.app_sessions s
join public.users u on u.id = s.user_id
left join lateral (
  -- 获取最新的订阅状态
  select status
  from public.subscriptions latest
  where latest.user_id = u.id
  order by latest.updated_at desc
  limit 1
) sub on true
left join public.usage_current usage on usage.user_id = u.id
where s.revoked_at is null                    -- 会话未撤销
  and (s.expires_at is null or s.expires_at > now());  -- 会话未过期

-- =============================================
-- 函数：increment_monthly_quota
-- 增加用户月度配额使用量
-- 安全定义器模式（security definer）：以函数创建者权限执行
-- =============================================
create or replace function public.increment_monthly_quota(
  p_user_id uuid,           -- 用户 ID
  p_request_count integer,  -- 请求次数增量
  p_token_count integer,    -- token 数增量
  p_cost numeric            -- 费用增量
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  current_month date := date_trunc('month', now())::date;  -- 当前月份
begin
  -- 使用 INSERT ... ON CONFLICT 实现 upsert
  insert into public.monthly_quotas (
    user_id,
    month,
    used_count,
    used_tokens,
    used_cost
  )
  values (
    p_user_id,
    current_month,
    p_request_count,
    p_token_count,
    p_cost
  )
  on conflict (user_id, month)  -- 如果已存在该用户当月记录
  do update set
    used_count = public.monthly_quotas.used_count + excluded.used_count,
    used_tokens = public.monthly_quotas.used_tokens + excluded.used_tokens,
    used_cost = public.monthly_quotas.used_cost + excluded.used_cost,
    updated_at = now();  -- 更新时间戳
end;
$$;
