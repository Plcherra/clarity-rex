alter table public.profiles
  add column if not exists proactive_insights_enabled boolean not null default false,
  add column if not exists proactive_insights_enabled_at timestamptz;

comment on column public.profiles.proactive_insights_enabled is
  'User opt-in for persisted deterministic financial insights. No background monitoring without explicit enablement.';
comment on column public.profiles.proactive_insights_enabled_at is
  'Timestamp when proactive_insights_enabled was last turned on.';

create table if not exists public.user_insights (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  fingerprint text not null,
  source text not null check (source in ('dashboard_snapshot', 'accountability')),
  insight_type text not null,
  title text not null,
  body text not null,
  anchor_key text,
  period_key text not null,
  payload_json jsonb not null default '{}'::jsonb,
  generated_at timestamptz not null default now(),
  read_at timestamptz,
  dismissed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists user_insights_user_fingerprint_uidx
  on public.user_insights(user_id, fingerprint);

create index if not exists user_insights_user_generated_idx
  on public.user_insights(user_id, generated_at desc);

create index if not exists user_insights_user_unread_idx
  on public.user_insights(user_id)
  where read_at is null and dismissed_at is null;

drop trigger if exists user_insights_set_updated_at on public.user_insights;
create trigger user_insights_set_updated_at
before update on public.user_insights
for each row
execute function public.set_updated_at();

alter table public.user_insights enable row level security;

drop policy if exists "Users can read their own insights" on public.user_insights;
create policy "Users can read their own insights" on public.user_insights
for select to authenticated
using (auth.uid() = user_id);

drop policy if exists "Users can insert their own insights" on public.user_insights;
create policy "Users can insert their own insights" on public.user_insights
for insert to authenticated
with check (auth.uid() = user_id);

drop policy if exists "Users can update their own insights" on public.user_insights;
create policy "Users can update their own insights" on public.user_insights
for update to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);
