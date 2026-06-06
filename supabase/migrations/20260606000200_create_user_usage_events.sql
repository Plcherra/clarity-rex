create table if not exists public.user_usage_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  event_type text not null check (length(trim(event_type)) > 0),
  surface text not null check (length(trim(surface)) > 0),
  feature text not null check (length(trim(feature)) > 0),
  channel text not null check (length(trim(channel)) > 0),
  provider text,
  model text,
  duration_ms integer check (duration_ms is null or duration_ms >= 0),
  latency_ms integer check (latency_ms is null or latency_ms >= 0),
  unit_count numeric(14,4) check (unit_count is null or unit_count >= 0),
  estimated_cost_cents numeric(14,6)
    check (estimated_cost_cents is null or estimated_cost_cents >= 0),
  status text not null default 'success'
    check (status in ('success', 'failure', 'partial', 'started', 'completed')),
  error_class text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  check (jsonb_typeof(metadata) = 'object'),
  check (
    not metadata ?| array[
      'prompt',
      'prompts',
      'response',
      'assistant_response',
      'reply',
      'message',
      'messages',
      'transcript',
      'audio',
      'audio_url',
      'audio_bytes',
      'plaid_access_token',
      'access_token',
      'public_token',
      'account_number',
      'routing_number',
      'transaction_description',
      'merchant',
      'merchant_name',
      'password',
      'mfa_code',
      'auth_token'
    ]
  )
);

create index if not exists user_usage_events_user_created_idx
  on public.user_usage_events (user_id, created_at desc);

create index if not exists user_usage_events_user_feature_created_idx
  on public.user_usage_events (user_id, feature, created_at desc);

create index if not exists user_usage_events_user_provider_created_idx
  on public.user_usage_events (user_id, provider, created_at desc)
  where provider is not null;

create index if not exists user_usage_events_created_idx
  on public.user_usage_events (created_at desc);

alter table public.user_usage_events enable row level security;

revoke all on public.user_usage_events from anon, authenticated;
