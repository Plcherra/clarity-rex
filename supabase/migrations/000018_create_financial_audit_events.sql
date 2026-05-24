create table if not exists public.financial_audit_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  event_type text not null check (length(trim(event_type)) > 0),
  entity_type text not null check (length(trim(entity_type)) > 0),
  entity_id text,
  source text not null default 'app' check (length(trim(source)) > 0),
  previous_value jsonb not null default '{}'::jsonb,
  new_value jsonb not null default '{}'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists financial_audit_events_user_created_idx
  on public.financial_audit_events (user_id, created_at desc);

create index if not exists financial_audit_events_user_entity_idx
  on public.financial_audit_events (user_id, entity_type, entity_id, created_at desc);

alter table public.financial_audit_events enable row level security;

drop policy if exists "Users can view their own financial audit events"
  on public.financial_audit_events;
create policy "Users can view their own financial audit events"
  on public.financial_audit_events
  for select
  using (auth.uid() = user_id);

drop policy if exists "Users can create their own financial audit events"
  on public.financial_audit_events;
create policy "Users can create their own financial audit events"
  on public.financial_audit_events
  for insert
  with check (auth.uid() = user_id);
