create index if not exists user_usage_events_simple_usage_idx
on public.user_usage_events (user_id, event_type, created_at desc);

drop policy if exists "Users can view their own usage events" on public.user_usage_events;
create policy "Users can view their own usage events"
on public.user_usage_events
for select
to authenticated
using (auth.uid() = user_id);

grant select on public.user_usage_events to authenticated;

create or replace view public.user_voice_summaries
with (security_invoker = true)
as
select
  user_id,
  created_at::date as usage_date,
  coalesce(
    sum(duration_ms) filter (where event_type = 'voice_session'),
    0
  )::numeric / 1000.0 as voice_seconds,
  count(*) filter (where event_type = 'llm')::integer as llm_calls,
  coalesce(
    sum(duration_ms) filter (where event_type = 'stt'),
    0
  )::numeric / 1000.0 as stt_seconds,
  coalesce(
    sum(duration_ms) filter (where event_type = 'tts'),
    0
  )::numeric / 1000.0 as tts_seconds
from public.user_usage_events
where event_type in (
  'llm',
  'stt',
  'tts',
  'voice_session'
)
group by user_id, created_at::date;

comment on view public.user_voice_summaries is
  'Daily voice/provider usage summary from canonical usage events only.';

grant select on public.user_voice_summaries to authenticated;
