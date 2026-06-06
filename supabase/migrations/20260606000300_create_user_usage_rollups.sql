create table if not exists public.user_usage_daily_rollups (
  user_id uuid not null references auth.users(id) on delete cascade,
  usage_date date not null,
  surface text not null default 'unknown',
  feature text not null default 'unknown',
  channel text not null default 'unknown',
  provider text not null default 'none',
  model text not null default 'none',
  event_type text not null default 'unknown',
  event_count integer not null default 0 check (event_count >= 0),
  success_count integer not null default 0 check (success_count >= 0),
  failure_count integer not null default 0 check (failure_count >= 0),
  total_duration_ms bigint not null default 0 check (total_duration_ms >= 0),
  total_latency_ms bigint not null default 0 check (total_latency_ms >= 0),
  avg_latency_ms numeric(14,4) check (avg_latency_ms is null or avg_latency_ms >= 0),
  total_unit_count numeric(14,4) not null default 0 check (total_unit_count >= 0),
  estimated_cost_cents numeric(14,6) not null default 0
    check (estimated_cost_cents >= 0),
  voice_minutes numeric(14,4) not null default 0 check (voice_minutes >= 0),
  updated_at timestamptz not null default now(),
  primary key (
    user_id,
    usage_date,
    surface,
    feature,
    channel,
    provider,
    model,
    event_type
  )
);

create index if not exists user_usage_daily_rollups_user_date_idx
  on public.user_usage_daily_rollups (user_id, usage_date desc);

drop trigger if exists user_usage_daily_rollups_set_updated_at
  on public.user_usage_daily_rollups;
create trigger user_usage_daily_rollups_set_updated_at
before update on public.user_usage_daily_rollups
for each row
execute function public.set_updated_at();

alter table public.user_usage_daily_rollups enable row level security;

drop policy if exists "Users can view their own usage daily rollups"
  on public.user_usage_daily_rollups;
create policy "Users can view their own usage daily rollups"
  on public.user_usage_daily_rollups
  for select to authenticated
  using (auth.uid() = user_id);

create or replace view public.user_usage_weekly_rollups
with (security_invoker = true) as
select
  user_id,
  'week'::text as period_type,
  date_trunc('week', usage_date::timestamp)::date as period_start,
  (date_trunc('week', usage_date::timestamp)::date + 6) as period_end,
  surface,
  feature,
  channel,
  provider,
  model,
  event_type,
  sum(event_count)::bigint as event_count,
  sum(success_count)::bigint as success_count,
  sum(failure_count)::bigint as failure_count,
  sum(total_duration_ms)::bigint as total_duration_ms,
  sum(total_latency_ms)::bigint as total_latency_ms,
  case
    when sum(event_count) > 0
      then round(sum(total_latency_ms)::numeric / sum(event_count), 4)
    else null
  end as avg_latency_ms,
  sum(total_unit_count)::numeric(14,4) as total_unit_count,
  sum(estimated_cost_cents)::numeric(14,6) as estimated_cost_cents,
  sum(voice_minutes)::numeric(14,4) as voice_minutes
from public.user_usage_daily_rollups
group by
  user_id,
  date_trunc('week', usage_date::timestamp)::date,
  surface,
  feature,
  channel,
  provider,
  model,
  event_type;

create or replace view public.user_usage_monthly_rollups
with (security_invoker = true) as
select
  user_id,
  'month'::text as period_type,
  date_trunc('month', usage_date::timestamp)::date as period_start,
  (
    date_trunc('month', usage_date::timestamp)::date
    + interval '1 month - 1 day'
  )::date as period_end,
  surface,
  feature,
  channel,
  provider,
  model,
  event_type,
  sum(event_count)::bigint as event_count,
  sum(success_count)::bigint as success_count,
  sum(failure_count)::bigint as failure_count,
  sum(total_duration_ms)::bigint as total_duration_ms,
  sum(total_latency_ms)::bigint as total_latency_ms,
  case
    when sum(event_count) > 0
      then round(sum(total_latency_ms)::numeric / sum(event_count), 4)
    else null
  end as avg_latency_ms,
  sum(total_unit_count)::numeric(14,4) as total_unit_count,
  sum(estimated_cost_cents)::numeric(14,6) as estimated_cost_cents,
  sum(voice_minutes)::numeric(14,4) as voice_minutes
from public.user_usage_daily_rollups
group by
  user_id,
  date_trunc('month', usage_date::timestamp)::date,
  surface,
  feature,
  channel,
  provider,
  model,
  event_type;

grant select on public.user_usage_daily_rollups to authenticated;
grant select on public.user_usage_weekly_rollups to authenticated;
grant select on public.user_usage_monthly_rollups to authenticated;
