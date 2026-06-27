alter table public.user_usage_events
  add column if not exists unit_count numeric(14,4)
    check (unit_count is null or unit_count >= 0),
  add column if not exists estimated_cost_cents numeric(14,6)
    check (estimated_cost_cents is null or estimated_cost_cents >= 0);

comment on column public.user_usage_events.unit_count is
  'Billable units: LLM tokens, STT/TTS minutes, or other provider units.';

comment on column public.user_usage_events.estimated_cost_cents is
  'Estimated provider cost in USD cents at event insert time.';

create or replace view public.owner_usage_daily
with (security_invoker = false)
as
select
  user_id,
  created_at::date as usage_date,
  coalesce(
    sum(duration_ms) filter (where event_type = 'voice_session'),
    0
  )::numeric / 1000.0 as voice_seconds,
  count(*) filter (
    where event_type = 'llm' and channel = 'chat'
  )::integer as chat_llm_calls,
  count(*) filter (
    where event_type = 'llm' and channel = 'voice'
  )::integer as voice_llm_calls,
  count(*) filter (where event_type = 'llm')::integer as llm_calls,
  coalesce(
    sum(duration_ms) filter (where event_type = 'stt'),
    0
  )::numeric / 1000.0 as stt_seconds,
  coalesce(
    sum(duration_ms) filter (where event_type = 'tts'),
    0
  )::numeric / 1000.0 as tts_seconds,
  coalesce(sum(estimated_cost_cents), 0) as estimated_cost_cents
from public.user_usage_events
where event_type in ('llm', 'stt', 'tts', 'voice_session')
group by user_id, created_at::date;

comment on view public.owner_usage_daily is
  'Daily per-user usage and estimated cost for owner billing dashboards.';

revoke all on public.owner_usage_daily from anon, authenticated;
