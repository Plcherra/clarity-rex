alter table public.profiles
add column if not exists assistant_settings jsonb not null default '{}'::jsonb;

comment on column public.profiles.assistant_settings is
  'Assistant companion preferences: auto_proposals_mode (off|text), auto_proposals_threads, auto_proposals_goals, auto_proposals_memory.';
