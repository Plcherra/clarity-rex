create extension if not exists vector with schema extensions;

create table if not exists public.chat_search_embeddings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  message_id uuid references public.messages(id) on delete cascade,
  source_kind text not null default 'message'
    check (source_kind in ('message', 'conversation_summary')),
  content_hash text not null,
  embedding_model text not null,
  embedding extensions.vector(1536) not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, content_hash, embedding_model)
);

alter table public.chat_search_embeddings enable row level security;

create policy "Users can read their own chat search embeddings"
  on public.chat_search_embeddings
  for select
  using (auth.uid() = user_id);

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
