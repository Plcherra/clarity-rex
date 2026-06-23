create extension if not exists pg_trgm with schema extensions;

create index if not exists messages_user_timestamp_idx
  on public.messages (user_id, timestamp desc);

create index if not exists messages_content_fts_idx
  on public.messages
  using gin (to_tsvector('simple', content));

create index if not exists messages_content_trgm_idx
  on public.messages
  using gin (lower(content) extensions.gin_trgm_ops);

create index if not exists conversations_title_fts_idx
  on public.conversations
  using gin (to_tsvector('simple', coalesce(title, '')));

create index if not exists conversations_title_trgm_idx
  on public.conversations
  using gin (lower(coalesce(title, '')) extensions.gin_trgm_ops);

create or replace function public.search_user_chat_messages(
  search_query text,
  search_terms text[] default array[]::text[],
  match_count integer default 50,
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
  with normalized_terms as (
    select distinct lower(trim(term)) as term
    from unnest(
      case
        when cardinality(coalesce(search_terms, array[]::text[])) > 0
          then search_terms
        else array[search_query]
      end
    ) as term
    where length(trim(term)) >= 2
  ),
  escaped_terms as (
    select
      term,
      regexp_replace(term, '([^a-z0-9 ])', '\\\1', 'g') as escaped_term
    from normalized_terms
  ),
  message_matches as (
    select
      m.id as message_id,
      m.conversation_id,
      m.role,
      m.content,
      m.timestamp as message_timestamp,
      c.title as conversation_title,
      c.timestamp as conversation_timestamp,
      array_agg(distinct et.term order by et.term) as matched_terms,
      max(
        ts_rank_cd(
          to_tsvector('simple', m.content),
          plainto_tsquery('simple', et.term)
        )
      ) as fts_score,
      max(similarity(lower(m.content), et.term)) as trigram_score,
      max(
        case
          when length(et.term) <= 2
            and lower(m.content) ~ ('(^|[^a-z0-9])' || et.escaped_term || '([^a-z0-9]|$)')
            then 1.0
          when length(et.term) > 2 and lower(m.content) like '%' || et.term || '%'
            then 1.0
          else 0.0
        end
      ) as exact_score
    from public.messages m
    join public.conversations c
      on c.user_id = m.user_id
     and c.id = m.conversation_id
    join escaped_terms et on true
    where m.user_id = auth.uid()
      and (exclude_conversation_id is null or m.conversation_id <> exclude_conversation_id)
      and (
        to_tsvector('simple', m.content) @@ plainto_tsquery('simple', et.term)
        or similarity(lower(m.content), et.term) >= 0.20
        or (
          length(et.term) <= 2
          and lower(m.content) ~ ('(^|[^a-z0-9])' || et.escaped_term || '([^a-z0-9]|$)')
        )
        or (
          length(et.term) > 2
          and lower(m.content) like '%' || et.term || '%'
        )
      )
    group by m.id, m.conversation_id, m.role, m.content, m.timestamp, c.title, c.timestamp
  ),
  title_matches as (
    select
      null::uuid as message_id,
      c.id as conversation_id,
      'conversation'::text as role,
      coalesce(c.title, '') as content,
      c.timestamp as message_timestamp,
      c.title as conversation_title,
      c.timestamp as conversation_timestamp,
      array_agg(distinct et.term order by et.term) as matched_terms,
      max(
        ts_rank_cd(
          to_tsvector('simple', coalesce(c.title, '')),
          plainto_tsquery('simple', et.term)
        )
      ) as fts_score,
      max(similarity(lower(coalesce(c.title, '')), et.term)) as trigram_score,
      max(
        case
          when length(et.term) <= 2
            and lower(coalesce(c.title, '')) ~ ('(^|[^a-z0-9])' || et.escaped_term || '([^a-z0-9]|$)')
            then 1.0
          when length(et.term) > 2 and lower(coalesce(c.title, '')) like '%' || et.term || '%'
            then 1.0
          else 0.0
        end
      ) as exact_score
    from public.conversations c
    join escaped_terms et on true
    where c.user_id = auth.uid()
      and (exclude_conversation_id is null or c.id <> exclude_conversation_id)
      and coalesce(c.title, '') <> ''
      and (
        to_tsvector('simple', coalesce(c.title, '')) @@ plainto_tsquery('simple', et.term)
        or similarity(lower(coalesce(c.title, '')), et.term) >= 0.20
        or (
          length(et.term) <= 2
          and lower(coalesce(c.title, '')) ~ ('(^|[^a-z0-9])' || et.escaped_term || '([^a-z0-9]|$)')
        )
        or (
          length(et.term) > 2
          and lower(coalesce(c.title, '')) like '%' || et.term || '%'
        )
      )
    group by c.id, c.title, c.timestamp
  ),
  combined as (
    select
      message_id,
      conversation_id,
      role,
      content,
      message_timestamp,
      conversation_title,
      conversation_timestamp,
      'message'::text as match_type,
      (
        (coalesce(exact_score, 0) * 4.0)
        + (coalesce(fts_score, 0) * 8.0)
        + (coalesce(trigram_score, 0) * 2.0)
        + case when role = 'user' then 1.5 else 0.4 end
      )::double precision as rank,
      matched_terms
    from message_matches
    union all
    select
      message_id,
      conversation_id,
      role,
      content,
      message_timestamp,
      conversation_title,
      conversation_timestamp,
      'title'::text as match_type,
      (
        (coalesce(exact_score, 0) * 4.0)
        + (coalesce(fts_score, 0) * 8.0)
        + (coalesce(trigram_score, 0) * 2.0)
        + 2.5
      )::double precision as rank,
      matched_terms
    from title_matches
  )
  select
    combined.message_id,
    combined.conversation_id,
    combined.role,
    combined.content,
    combined.message_timestamp,
    combined.conversation_title,
    combined.conversation_timestamp,
    combined.match_type,
    combined.rank,
    case
      when combined.match_type = 'title' then 'Matched conversation title with indexed chat search.'
      else 'Matched message content with indexed chat search.'
    end as search_reason,
    combined.matched_terms
  from combined
  order by combined.rank desc, combined.message_timestamp desc
  limit greatest(1, least(coalesce(match_count, 50), 200));
$$;

grant execute on function public.search_user_chat_messages(text, text[], integer, uuid)
  to authenticated;
