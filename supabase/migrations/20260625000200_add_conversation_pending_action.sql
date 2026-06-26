alter table public.conversations
  add column if not exists pending_action jsonb;

comment on column public.conversations.pending_action is
  'Optional durable pending Rex action awaiting user confirmation (delete/update).';
