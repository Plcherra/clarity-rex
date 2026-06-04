-- Phase 9 Rex simplification cleanup.
--
-- The product no longer uses pending memory candidates, memory confirmation
-- rows, or candidate review sessions. Archive any remaining rows for safety,
-- then remove the old runtime tables.

do $$
begin
  if to_regclass('public.memory_candidates') is not null then
    if to_regclass('public.legacy_memory_candidates_archive') is null then
      execute '
        create table public.legacy_memory_candidates_archive as
        select *, now() as archived_at
        from public.memory_candidates
      ';
    else
      execute '
        insert into public.legacy_memory_candidates_archive
        select c.*, now() as archived_at
        from public.memory_candidates c
        where not exists (
          select 1
          from public.legacy_memory_candidates_archive a
          where a.id = c.id
        )
      ';
    end if;

    drop trigger if exists set_memory_candidates_updated_at
      on public.memory_candidates;
    drop policy if exists "Users can manage their own memory candidates"
      on public.memory_candidates;
    drop table public.memory_candidates;
  end if;

  if to_regclass('public.memory_confirmations') is not null then
    if to_regclass('public.legacy_memory_confirmations_archive') is null then
      execute '
        create table public.legacy_memory_confirmations_archive as
        select *, now() as archived_at
        from public.memory_confirmations
      ';
    else
      execute '
        insert into public.legacy_memory_confirmations_archive
        select c.*, now() as archived_at
        from public.memory_confirmations c
        where not exists (
          select 1
          from public.legacy_memory_confirmations_archive a
          where a.id = c.id
        )
      ';
    end if;

    drop trigger if exists set_memory_confirmations_updated_at
      on public.memory_confirmations;
    drop policy if exists "Users can manage their own memory confirmations"
      on public.memory_confirmations;
    drop table public.memory_confirmations;
  end if;

  if to_regclass('public.memory_candidate_review_sessions') is not null then
    if to_regclass('public.legacy_memory_candidate_review_sessions_archive') is null then
      execute '
        create table public.legacy_memory_candidate_review_sessions_archive as
        select *, now() as archived_at
        from public.memory_candidate_review_sessions
      ';
    else
      execute '
        insert into public.legacy_memory_candidate_review_sessions_archive
        select s.*, now() as archived_at
        from public.memory_candidate_review_sessions s
        where not exists (
          select 1
          from public.legacy_memory_candidate_review_sessions_archive a
          where a.id = s.id
        )
      ';
    end if;

    drop trigger if exists set_memory_candidate_review_sessions_updated_at
      on public.memory_candidate_review_sessions;
    drop policy if exists "Users can manage their own memory candidate review sessions"
      on public.memory_candidate_review_sessions;
    drop table public.memory_candidate_review_sessions;
  end if;
end $$;

do $$
declare
  archive_table text;
begin
  foreach archive_table in array array[
    'legacy_memory_candidates_archive',
    'legacy_memory_confirmations_archive',
    'legacy_memory_candidate_review_sessions_archive'
  ]
  loop
    if to_regclass('public.' || archive_table) is not null then
      execute format('alter table public.%I enable row level security', archive_table);
      execute format(
        'drop policy if exists "Users can read their own %s" on public.%I',
        archive_table,
        archive_table
      );
      execute format(
        'create policy "Users can read their own %s" on public.%I for select to authenticated using (auth.uid() = user_id)',
        archive_table,
        archive_table
      );
      execute format(
        'comment on table public.%I is %L',
        archive_table,
        'Legacy Rex memory review data archived during the simplified direct-memory migration. This table is read-only for users and not used by product code.'
      );
    end if;
  end loop;
end $$;
