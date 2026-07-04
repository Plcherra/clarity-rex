create table if not exists public.open_threads (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  summary text,
  status text not null default 'active' check (
    status in ('active', 'paused', 'closed')
  ),
  source text not null default 'user_confirmed' check (
    source in ('user_confirmed', 'user_created')
  ),
  source_conversation_id uuid,
  source_message_id uuid,
  last_mentioned_at timestamptz,
  last_follow_up_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint open_threads_user_id_id_uidx unique (user_id, id),
  constraint open_threads_source_conversation_user_fk
    foreign key (user_id, source_conversation_id)
    references public.conversations(user_id, id)
    on delete set null (source_conversation_id),
  constraint open_threads_source_message_user_fk
    foreign key (user_id, source_message_id)
    references public.messages(user_id, id)
    on delete set null (source_message_id)
);

create index if not exists open_threads_user_status_updated_idx
  on public.open_threads (user_id, status, updated_at desc);

create index if not exists open_threads_user_active_idx
  on public.open_threads (user_id, status)
  where status = 'active';

drop trigger if exists set_open_threads_updated_at on public.open_threads;
create trigger set_open_threads_updated_at
before update on public.open_threads
for each row
execute function public.set_updated_at();

alter table public.open_threads enable row level security;

drop policy if exists "Users can manage their own open threads"
  on public.open_threads;
create policy "Users can manage their own open threads"
on public.open_threads
for all to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);
