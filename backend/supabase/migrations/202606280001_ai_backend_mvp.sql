create extension if not exists pgcrypto;

create table if not exists public.users (
  id uuid primary key default gen_random_uuid(),
  apple_user_id text not null unique,
  email text,
  display_name text,
  country_code text,
  storefront text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.app_sessions (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.users(id) on delete cascade,
  token_hash text not null unique,
  created_at timestamptz not null default now(),
  expires_at timestamptz,
  revoked_at timestamptz
);

create table if not exists public.subscriptions (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.users(id) on delete cascade,
  product_id text not null,
  original_transaction_id text not null unique,
  latest_transaction_id text not null,
  status text not null,
  expires_at timestamptz,
  environment text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint subscriptions_status_check check (
    status in ('active', 'inactive', 'expired', 'refunded', 'grace_period')
  ),
  constraint subscriptions_environment_check check (
    environment in ('Sandbox', 'Production')
  )
);

create table if not exists public.usage_records (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.users(id) on delete cascade,
  request_id text not null,
  request_type text not null,
  model text,
  image_bytes integer not null default 0,
  image_count integer not null default 0,
  input_token_count integer not null default 0,
  output_token_count integer not null default 0,
  estimated_cost numeric(12, 6) not null default 0,
  billable boolean not null default false,
  status text not null,
  output_text text,
  created_at timestamptz not null default now(),
  constraint usage_records_request_type_check check (
    request_type in ('analyze_screenshot')
  ),
  constraint usage_records_status_check check (
    status in ('accepted', 'blocked', 'succeeded', 'failed')
  ),
  constraint usage_records_request_id_unique unique (user_id, request_id)
);

create table if not exists public.monthly_quotas (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.users(id) on delete cascade,
  month date not null,
  used_count integer not null default 0,
  limit_count integer not null default 100,
  used_tokens integer not null default 0,
  limit_tokens integer not null default 120000,
  used_cost numeric(12, 6) not null default 0,
  limit_cost numeric(12, 6) not null default 5,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint monthly_quotas_user_month_unique unique (user_id, month)
);

create table if not exists public.abuse_events (
  id bigint generated always as identity primary key,
  user_id uuid references public.users(id) on delete set null,
  ip inet,
  reason text not null,
  detail jsonb,
  created_at timestamptz not null default now()
);

create index if not exists app_sessions_user_id_idx on public.app_sessions(user_id);
create index if not exists subscriptions_user_id_idx on public.subscriptions(user_id);
create index if not exists subscriptions_status_expires_at_idx on public.subscriptions(status, expires_at);
create index if not exists usage_records_user_id_created_at_idx on public.usage_records(user_id, created_at desc);
create index if not exists monthly_quotas_user_id_month_idx on public.monthly_quotas(user_id, month desc);
create index if not exists abuse_events_user_id_created_at_idx on public.abuse_events(user_id, created_at desc);

alter table public.users enable row level security;
alter table public.app_sessions enable row level security;
alter table public.subscriptions enable row level security;
alter table public.usage_records enable row level security;
alter table public.monthly_quotas enable row level security;
alter table public.abuse_events enable row level security;

create or replace view public.usage_current as
select
  u.id as user_id,
  coalesce(mq.used_count, 0) as monthly_used_count,
  coalesce(mq.limit_count, 100) as monthly_limit_count,
  coalesce(today.daily_used_count, 0) as daily_used_count,
  20 as daily_limit_count
from public.users u
left join public.monthly_quotas mq
  on mq.user_id = u.id
  and mq.month = date_trunc('month', now())::date
left join lateral (
  select count(*)::integer as daily_used_count
  from public.usage_records ur
  where ur.user_id = u.id
    and ur.billable = true
    and ur.status = 'succeeded'
    and ur.created_at >= date_trunc('day', now())
) today on true;

create or replace view public.user_ai_access as
select
  s.token_hash,
  u.id,
  u.country_code,
  u.storefront,
  coalesce(sub.status, 'inactive') as subscription_status,
  coalesce(usage.monthly_used_count, 0) as monthly_used_count,
  coalesce(usage.daily_used_count, 0) as daily_used_count
from public.app_sessions s
join public.users u on u.id = s.user_id
left join lateral (
  select status
  from public.subscriptions latest
  where latest.user_id = u.id
  order by latest.updated_at desc
  limit 1
) sub on true
left join public.usage_current usage on usage.user_id = u.id
where s.revoked_at is null
  and (s.expires_at is null or s.expires_at > now());

create or replace function public.increment_monthly_quota(
  p_user_id uuid,
  p_request_count integer,
  p_token_count integer,
  p_cost numeric
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  current_month date := date_trunc('month', now())::date;
begin
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
  on conflict (user_id, month)
  do update set
    used_count = public.monthly_quotas.used_count + excluded.used_count,
    used_tokens = public.monthly_quotas.used_tokens + excluded.used_tokens,
    used_cost = public.monthly_quotas.used_cost + excluded.used_cost,
    updated_at = now();
end;
$$;
