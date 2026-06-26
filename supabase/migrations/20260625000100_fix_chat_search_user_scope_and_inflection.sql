-- Allow explicit user scoping for backend service-role calls and expand
-- singular/plural search terms generically inside the RPC.
create or replace function public.search_user_chat_messages(
  search_query text,
  search_terms text[] default array[]::text[],
  match_count integer default 50,
  exclude_conversation_id uuid default null,
  match_user_id uuid default null
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
  with scoped_user as (
    select coalesce(auth.uid(), match_user_id) as user_id
  ),
  normalized_terms as (
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
  expanded_terms as (
    select term from normalized_terms
    union
    select left(term, length(term) - 1) as term
    from normalized_terms
    where length(term) > 3
      and right(term, 1) = 's'
      and right(term, 2) <> 'ss'
    union
    select term || 's' as term
    from normalized_terms
    where length(term) >= 3
      and right(term, 1) <> 's'
  ),
  escaped_terms as (
    select
      term,
      regexp_replace(term, '([^a-z0-9 ])', '\\\1', 'g') as escaped_term
    from expanded_terms
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
    join scoped_user su on true
    join escaped_terms et on true
    where su.user_id is not null
      and m.user_id = su.user_id
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
    join scoped_user su on true
    join escaped_terms et on true
    where su.user_id is not null
      and c.user_id = su.user_id
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

grant execute on function public.search_user_chat_messages(
  text,
  text[],
  integer,
  uuid,
  uuid
) to authenticated;
