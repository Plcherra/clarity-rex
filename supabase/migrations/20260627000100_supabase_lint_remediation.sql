-- Supabase database linter remediation (2026-06-27).
-- Fixes: function search_path, RLS initplan (auth.uid), backend-only RLS policies,
-- unindexed foreign keys, and legacy archive primary keys.

-- ---------------------------------------------------------------------------
-- 1. Function search_path (security lint 0011)
-- ---------------------------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.normalize_category_name(input text)
returns text
language sql
immutable
set search_path = public
as $$
  select nullif(
    regexp_replace(
      regexp_replace(
        replace(lower(trim(coalesce(input, ''))), '&', ' and '),
        '[^a-z0-9]+',
        ' ',
        'g'
      ),
      '[[:space:]]+',
      ' ',
      'g'
    ),
    ''
  );
$$;

create or replace function public.set_category_normalized_name()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.normalized_name := public.normalize_category_name(new.name);
  if new.normalized_name is null or trim(new.normalized_name) = '' then
    raise exception 'Category name cannot be normalized';
  end if;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. RLS initplan: wrap auth.uid() as (select auth.uid()) (lint 0003)
-- ---------------------------------------------------------------------------

-- profiles (uses id, not user_id)
drop policy if exists "Users can read their own profile" on public.profiles;
create policy "Users can read their own profile" on public.profiles
for select to authenticated
using ((select auth.uid()) = id);

drop policy if exists "Users can insert their own profile" on public.profiles;
create policy "Users can insert their own profile" on public.profiles
for insert to authenticated
with check ((select auth.uid()) = id);

drop policy if exists "Users can update their own profile" on public.profiles;
create policy "Users can update their own profile" on public.profiles
for update to authenticated
using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);

-- financial core
drop policy if exists "Users can manage their own accounts" on public.accounts;
create policy "Users can manage their own accounts" on public.accounts
for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can manage their own categories" on public.categories;
create policy "Users can manage their own categories" on public.categories
for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can manage their own budgets" on public.budgets;
create policy "Users can manage their own budgets" on public.budgets
for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can manage their own transactions" on public.transactions;
create policy "Users can manage their own transactions" on public.transactions
for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can manage their own merchant category rules"
  on public.merchant_category_rules;
create policy "Users can manage their own merchant category rules"
on public.merchant_category_rules
for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can manage their own statement imports"
  on public.account_statement_imports;
create policy "Users can manage their own statement imports"
on public.account_statement_imports
for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can view their own financial audit events"
  on public.financial_audit_events;
create policy "Users can view their own financial audit events"
on public.financial_audit_events
for select to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "Users can create their own financial audit events"
  on public.financial_audit_events;
create policy "Users can create their own financial audit events"
on public.financial_audit_events
for insert to authenticated
with check ((select auth.uid()) = user_id);

-- Rex assistant
drop policy if exists "Users can manage their own assistant conversations"
  on public.conversations;
create policy "Users can manage their own assistant conversations"
on public.conversations
for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can manage their own assistant messages" on public.messages;
create policy "Users can manage their own assistant messages"
on public.messages
for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can manage their own long term memory"
  on public.long_term_memory;
create policy "Users can manage their own long term memory"
on public.long_term_memory
for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can manage their own memory corrections"
  on public.memory_corrections;
create policy "Users can manage their own memory corrections"
on public.memory_corrections
for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can manage their own entities" on public.entities;
create policy "Users can manage their own entities"
on public.entities
for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can manage their own entity events" on public.entity_events;
create policy "Users can manage their own entity events"
on public.entity_events
for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can manage their own personal rules" on public.personal_rules;
create policy "Users can manage their own personal rules"
on public.personal_rules
for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can manage their own plans" on public.plans;
create policy "Users can manage their own plans"
on public.plans
for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can manage their own plan milestones" on public.plan_milestones;
create policy "Users can manage their own plan milestones"
on public.plan_milestones
for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can manage their own commitments" on public.commitments;
create policy "Users can manage their own commitments"
on public.commitments
for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can manage their own voice turns" on public.voice_turns;
create policy "Users can manage their own voice turns"
on public.voice_turns
for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

-- Plaid (read-only for clients; tokens stay backend-only)
drop policy if exists "Users can view their own Plaid items" on public.plaid_items;
create policy "Users can view their own Plaid items"
on public.plaid_items
for select to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "Users can view their own Plaid accounts" on public.plaid_accounts;
create policy "Users can view their own Plaid accounts"
on public.plaid_accounts
for select to authenticated
using ((select auth.uid()) = user_id);

-- Usage
drop policy if exists "Users can view their own usage events" on public.user_usage_events;
create policy "Users can view their own usage events"
on public.user_usage_events
for select to authenticated
using ((select auth.uid()) = user_id);

-- Chat search embeddings
drop policy if exists "Users can read their own chat search embeddings"
  on public.chat_search_embeddings;
create policy "Users can read their own chat search embeddings"
on public.chat_search_embeddings
for select to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "Users can insert their own chat search embeddings"
  on public.chat_search_embeddings;
create policy "Users can insert their own chat search embeddings"
on public.chat_search_embeddings
for insert to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update their own chat search embeddings"
  on public.chat_search_embeddings;
create policy "Users can update their own chat search embeddings"
on public.chat_search_embeddings
for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

-- Legacy Rex memory review archives (read-only)
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
      execute format(
        'drop policy if exists "Users can read their own %s" on public.%I',
        archive_table,
        archive_table
      );
      execute format(
        'create policy "Users can read their own %s" on public.%I for select to authenticated using ((select auth.uid()) = user_id)',
        archive_table,
        archive_table
      );
    end if;
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 3. Backend-only tables: explicit deny policies (lint 0008)
-- ---------------------------------------------------------------------------

drop policy if exists "No direct client access" on public.admin_users;
create policy "No direct client access"
on public.admin_users
for all to authenticated
using (false)
with check (false);

revoke all on public.admin_users from anon, authenticated;

drop policy if exists "No direct client access" on public.plaid_item_secrets;
create policy "No direct client access"
on public.plaid_item_secrets
for all to authenticated
using (false)
with check (false);

revoke all on public.plaid_item_secrets from anon, authenticated;

comment on policy "No direct client access" on public.admin_users is
  'Admin roster is backend/service-role only. RLS deny policy documents intent for the linter.';

comment on policy "No direct client access" on public.plaid_item_secrets is
  'Plaid access tokens are backend/service-role only. RLS deny policy documents intent for the linter.';

-- ---------------------------------------------------------------------------
-- 4. Unindexed foreign keys (lint 0001)
-- ---------------------------------------------------------------------------

create index if not exists account_statement_imports_account_id_idx
  on public.account_statement_imports (account_id);

create index if not exists admin_users_created_by_idx
  on public.admin_users (created_by);

create index if not exists budgets_category_id_idx
  on public.budgets (category_id);

create index if not exists chat_search_embeddings_conversation_id_fkey_idx
  on public.chat_search_embeddings (conversation_id);

create index if not exists chat_search_embeddings_message_id_fkey_idx
  on public.chat_search_embeddings (message_id)
  where message_id is not null;

create index if not exists commitments_user_source_conversation_idx
  on public.commitments (user_id, source_conversation_id);

create index if not exists commitments_user_source_memory_idx
  on public.commitments (user_id, source_memory_id);

create index if not exists commitments_user_source_message_idx
  on public.commitments (user_id, source_message_id);

create index if not exists entities_user_source_memory_idx
  on public.entities (user_id, source_memory_id);

create index if not exists entities_user_source_message_idx
  on public.entities (user_id, source_message_id);

create index if not exists entity_events_user_source_conversation_idx
  on public.entity_events (user_id, source_conversation_id);

create index if not exists entity_events_user_source_memory_idx
  on public.entity_events (user_id, source_memory_id);

create index if not exists entity_events_user_source_message_idx
  on public.entity_events (user_id, source_message_id);

create index if not exists long_term_memory_user_source_message_idx
  on public.long_term_memory (user_id, source_message_id);

create index if not exists long_term_memory_user_superseded_by_idx
  on public.long_term_memory (user_id, superseded_by);

create index if not exists memory_corrections_user_source_conversation_idx
  on public.memory_corrections (user_id, source_conversation_id);

create index if not exists memory_corrections_user_source_message_idx
  on public.memory_corrections (user_id, source_message_id);

create index if not exists personal_rules_user_source_conversation_idx
  on public.personal_rules (user_id, source_conversation_id);

create index if not exists personal_rules_user_source_memory_idx
  on public.personal_rules (user_id, source_memory_id);

create index if not exists personal_rules_user_source_message_idx
  on public.personal_rules (user_id, source_message_id);

create index if not exists plan_milestones_user_source_conversation_idx
  on public.plan_milestones (user_id, source_conversation_id);

create index if not exists plan_milestones_user_source_memory_idx
  on public.plan_milestones (user_id, source_memory_id);

create index if not exists plan_milestones_user_source_message_idx
  on public.plan_milestones (user_id, source_message_id);

create index if not exists plans_user_source_conversation_idx
  on public.plans (user_id, source_conversation_id);

create index if not exists plans_user_source_memory_idx
  on public.plans (user_id, source_memory_id);

create index if not exists plans_user_source_message_idx
  on public.plans (user_id, source_message_id);

create index if not exists transactions_user_account_idx
  on public.transactions (user_id, account_id);

create index if not exists transactions_user_category_idx
  on public.transactions (user_id, category_id);

create index if not exists voice_turns_user_user_message_idx
  on public.voice_turns (user_id, user_message_id);

create index if not exists voice_turns_user_assistant_message_idx
  on public.voice_turns (user_id, assistant_message_id);

-- ---------------------------------------------------------------------------
-- 5. Legacy archive primary keys (lint 0004)
-- ---------------------------------------------------------------------------

do $$
begin
  if to_regclass('public.legacy_memory_candidates_archive') is not null
     and not exists (
       select 1
       from pg_constraint
       where conrelid = 'public.legacy_memory_candidates_archive'::regclass
         and contype = 'p'
     ) then
    alter table public.legacy_memory_candidates_archive
      add primary key (id);
  end if;

  if to_regclass('public.legacy_memory_confirmations_archive') is not null
     and not exists (
       select 1
       from pg_constraint
       where conrelid = 'public.legacy_memory_confirmations_archive'::regclass
         and contype = 'p'
     ) then
    alter table public.legacy_memory_confirmations_archive
      add primary key (id);
  end if;

  if to_regclass('public.legacy_memory_candidate_review_sessions_archive') is not null
     and not exists (
       select 1
       from pg_constraint
       where conrelid = 'public.legacy_memory_candidate_review_sessions_archive'::regclass
         and contype = 'p'
     ) then
    alter table public.legacy_memory_candidate_review_sessions_archive
      add primary key (id);
  end if;
end $$;
