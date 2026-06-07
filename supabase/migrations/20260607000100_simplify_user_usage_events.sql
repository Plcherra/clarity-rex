drop view if exists public.user_usage_monthly_rollups;
drop view if exists public.user_usage_weekly_rollups;

drop table if exists public.user_usage_daily_rollups;

alter table public.user_usage_events
  drop column if exists unit_count,
  drop column if exists estimated_cost_cents,
  drop column if exists metadata;

comment on table public.user_usage_events is
  'Safe provider usage events only: STT, LLM, TTS, and voice session durations.';
