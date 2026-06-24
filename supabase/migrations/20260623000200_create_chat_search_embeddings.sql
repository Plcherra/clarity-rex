create extension if not exists vector with schema extensions;

create table if not exists public.chat_search_embeddings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  message_id uuid references public.messages(id) on delete cascade,
  source_kind text not null default 'message'
    check (source_kind in ('message', 'conversation_summary')),
  content text not null default '',
  content_hash text not null,
  embedding_model text not null,
  embedding extensions.vector(1536) not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, content_hash, embedding_model)
);

alter table public.chat_search_embeddings
  add column if not exists content text not null default '';

alter table public.chat_search_embeddings enable row level security;

create policy "Users can read their own chat search embeddings"
  on public.chat_search_embeddings
  for select
  using (auth.uid() = user_id);

create policy "Users can insert their own chat search embeddings"
  on public.chat_search_embeddings
  for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own chat search embeddings"
  on public.chat_search_embeddings
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create index if not exists chat_search_embeddings_user_created_idx
  on public.chat_search_embeddings (user_id, created_at desc);

create index if not exists chat_search_embeddings_conversation_idx
  on public.chat_search_embeddings (user_id, conversation_id);

create index if not exists chat_search_embeddings_message_idx
  on public.chat_search_embeddings (user_id, message_id)
  where message_id is not null;

create index if not exists chat_search_embeddings_vector_idx
  on public.chat_search_embeddings
  using hnsw (embedding extensions.vector_cosine_ops);

create or replace function public.match_user_chat_search_embeddings(
  query_embedding extensions.vector(1536),
  match_embedding_model text,
  match_threshold double precision default 0.72,
  match_count integer default 20,
  exclude_conversation_id uuid default null
)
returns table (
  message_id uuid,
  conversation_id uuid,
  role text,
  content text,
  message_timestamp timestamptz,
  conversation_title text,
  conversation_timestamp timestamptz,
  match_type text,
  rank double precision,
  search_reason text,
  matched_terms text[]
)
language sql
stable
security invoker
set search_path = public, extensions
as $$
  select
    e.message_id,
    e.conversation_id,
    coalesce(m.role, e.source_kind) as role,
    coalesce(nullif(e.content, ''), m.content, c.title, '') as content,
    coalesce(m.timestamp, c.timestamp) as message_timestamp,
    c.title as conversation_title,
    c.timestamp as conversation_timestamp,
    case
      when e.source_kind = 'conversation_summary' then 'conversation_summary'
      else 'semantic_message'
    end as match_type,
    ((1 - (e.embedding <=> query_embedding)) * 10.0)::double precision as rank,
    case
      when e.source_kind = 'conversation_summary'
        then 'Matched conversation summary with semantic chat search.'
      else 'Matched message content with semantic chat search.'
    end as search_reason,
    array[]::text[] as matched_terms
  from public.chat_search_embeddings e
  join public.conversations c
    on c.user_id = e.user_id
   and c.id = e.conversation_id
  left join public.messages m
    on m.user_id = e.user_id
   and m.id = e.message_id
  where e.user_id = auth.uid()
    and e.embedding_model = match_embedding_model
    and (exclude_conversation_id is null or e.conversation_id <> exclude_conversation_id)
    and (1 - (e.embedding <=> query_embedding)) > match_threshold
  order by e.embedding <=> query_embedding asc
  limit greatest(1, least(coalesce(match_count, 20), 200));
$$;

grant execute on function public.match_user_chat_search_embeddings(
  extensions.vector(1536),
  text,
  double precision,
  integer,
  uuid
) to authenticated;
