create table if not exists public.memory_confirmations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  conversation_id uuid not null,
  source_message_id uuid,
  confirmation_message_id uuid,
  status text not null default 'pending' check (
    status in ('pending', 'confirmed', 'rejected', 'expired', 'failed')
  ),
  memory_type text not null check (
    memory_type in ('fact', 'preference', 'event')
  ),
  content text not null,
  importance integer not null default 3 check (importance between 1 and 5),
  source text not null default 'simple_memory_intent',
  expires_at timestamptz not null default (now() + interval '48 hours'),
  confirmed_at timestamptz,
  rejected_at timestamptz,
  failed_at timestamptz,
  applied_memory_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint memory_confirmations_user_id_id_uidx unique (user_id, id),
  constraint memory_confirmations_conversation_user_fk
    foreign key (user_id, conversation_id)
    references public.conversations(user_id, id)
    on delete cascade,
  constraint memory_confirmations_source_message_user_fk
    foreign key (user_id, source_message_id)
    references public.messages(user_id, id)
    on delete set null (source_message_id),
  constraint memory_confirmations_confirmation_message_user_fk
    foreign key (user_id, confirmation_message_id)
    references public.messages(user_id, id)
    on delete set null (confirmation_message_id),
  constraint memory_confirmations_applied_memory_user_fk
    foreign key (user_id, applied_memory_id)
    references public.long_term_memory(user_id, id)
    on delete set null (applied_memory_id)
);

create index if not exists memory_confirmations_user_conversation_pending_idx
  on public.memory_confirmations (user_id, conversation_id, created_at desc)
  where status = 'pending';

create index if not exists memory_confirmations_user_status_created_idx
  on public.memory_confirmations (user_id, status, created_at desc);

create index if not exists memory_confirmations_user_topic_pending_idx
  on public.memory_confirmations (
    user_id,
    ((metadata->>'topic_fingerprint')),
    created_at desc
  )
  where status = 'pending' and metadata ? 'topic_fingerprint';

drop trigger if exists set_memory_confirmations_updated_at
  on public.memory_confirmations;
create trigger set_memory_confirmations_updated_at
before update on public.memory_confirmations
for each row
execute function public.set_updated_at();

comment on table public.memory_confirmations is
  'Explicit pending simple-memory confirmations for Rex chat and voice flows.';

comment on column public.memory_confirmations.metadata is
  'Supported keys include topic_fingerprint, fact_kind, entity_label, normalized_date, original_text, and error.';
