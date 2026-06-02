create table if not exists public.memory_candidate_review_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  conversation_id uuid not null,
  candidate_ids jsonb not null default '[]'::jsonb,
  status text not null default 'active' check (
    status in ('active', 'completed', 'expired')
  ),
  expires_at timestamptz not null default (now() + interval '30 minutes'),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint memory_candidate_review_sessions_user_id_id_uidx
    unique (user_id, id),
  constraint memory_candidate_review_sessions_candidate_ids_array_chk
    check (jsonb_typeof(candidate_ids) = 'array'),
  constraint memory_candidate_review_sessions_conversation_user_fk
    foreign key (user_id, conversation_id)
    references public.conversations(user_id, id)
    on delete cascade
);

create index if not exists memory_candidate_review_sessions_active_idx
  on public.memory_candidate_review_sessions (
    user_id,
    conversation_id,
    status,
    created_at desc
  )
  where status = 'active';

create index if not exists memory_candidate_review_sessions_expires_idx
  on public.memory_candidate_review_sessions (user_id, expires_at)
  where status = 'active';

drop trigger if exists set_memory_candidate_review_sessions_updated_at
  on public.memory_candidate_review_sessions;
create trigger set_memory_candidate_review_sessions_updated_at
before update on public.memory_candidate_review_sessions
for each row
execute function public.set_updated_at();

alter table public.memory_candidate_review_sessions enable row level security;

drop policy if exists "Users can manage their own memory candidate review sessions"
  on public.memory_candidate_review_sessions;
create policy "Users can manage their own memory candidate review sessions"
on public.memory_candidate_review_sessions
for all to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

comment on table public.memory_candidate_review_sessions is
  'Explicit review sessions for pending Rex memory candidates referenced by those/these/them confirmations.';

comment on column public.memory_candidate_review_sessions.candidate_ids is
  'Ordered candidate IDs shown to the user for one review operation. Stores IDs only, not memory content.';

comment on column public.memory_candidate_review_sessions.metadata is
  'Safe review metadata such as high_risk_candidate_ids and source.';

