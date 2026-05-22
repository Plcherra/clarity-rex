-- Phase 4 category cleanup.
-- Idempotent data repair:
-- 1. Ensures every user with categories or transactions has an Unknown category.
-- 2. Moves transactions from invalid categories to that user's Unknown category.
-- 3. Moves transactions with null category_id to that user's Unknown category.
-- 4. Deletes invalid category rows once unreferenced.
--
-- This intentionally does not delete or rewrite valid user-created categories.

begin;

create temp table phase4_users_to_check on commit drop as
select distinct user_id from public.categories
union
select distinct user_id from public.transactions;

insert into public.categories (user_id, name, normalized_name, type)
select u.user_id, 'Unknown', 'unknown', 'expense'
from phase4_users_to_check u
where not exists (
  select 1
  from public.categories c
  where c.user_id = u.user_id
    and c.normalized_name = 'unknown'
)
on conflict (user_id, normalized_name) do nothing;

create temp table phase4_unknown_categories on commit drop as
select c.user_id, c.id
from public.categories c
join phase4_users_to_check u
  on u.user_id = c.user_id
where c.normalized_name = 'unknown';

create temp table phase4_invalid_categories on commit drop as
select
  c.user_id,
  c.id as category_id,
  c.name as category_name,
  c.normalized_name,
  case
    when trim(c.name) = '' then 'empty'
    when char_length(trim(c.name)) > 40 then 'too_long'
    when lower(trim(c.name)) like 'http://%' then 'unsafe'
    when lower(trim(c.name)) like 'https://%' then 'unsafe'
    when position('@' in c.name) > 0 then 'unsafe'
    when c.name ~ '[<>{}\[\]\\`~^=]' then 'unsafe'
    when c.name !~ '[A-Za-z0-9]' then 'no_alphanumeric'
    when char_length(regexp_replace(c.name, '[^A-Za-z0-9]', '', 'g')) < 3 then 'too_short'
    when nullif(
      regexp_replace(
        regexp_replace(
          replace(lower(trim(coalesce(c.name, ''))), '&', ' and '),
          '[^a-z0-9]+',
          ' ',
          'g'
        ),
        '[[:space:]]+',
        ' ',
        'g'
      ),
      ''
    ) is null then 'empty_normalized'
    else 'unknown'
  end as reason
from public.categories c
where lower(trim(c.name)) <> 'unknown'
  and (
    trim(c.name) = ''
    or char_length(trim(c.name)) > 40
    or lower(trim(c.name)) like 'http://%'
    or lower(trim(c.name)) like 'https://%'
    or position('@' in c.name) > 0
    or c.name ~ '[<>{}\[\]\\`~^=]'
    or c.name !~ '[A-Za-z0-9]'
    or char_length(regexp_replace(c.name, '[^A-Za-z0-9]', '', 'g')) < 3
    or nullif(
      regexp_replace(
        regexp_replace(
          replace(lower(trim(coalesce(c.name, ''))), '&', ' and '),
          '[^a-z0-9]+',
          ' ',
          'g'
        ),
        '[[:space:]]+',
        ' ',
        'g'
      ),
      ''
    ) is null
  );

create temp table phase4_cleanup_summary (
  invalid_categories_found bigint not null,
  invalid_category_transactions_reassigned bigint not null,
  null_category_transactions_reassigned bigint not null,
  invalid_categories_deleted bigint not null
);

with updated as (
  update public.transactions t
  set category_id = u.id
  from phase4_invalid_categories i
  join phase4_unknown_categories u
    on u.user_id = i.user_id
  where t.user_id = i.user_id
    and t.category_id = i.category_id
  returning t.id
)
insert into phase4_cleanup_summary (
  invalid_categories_found,
  invalid_category_transactions_reassigned,
  null_category_transactions_reassigned,
  invalid_categories_deleted
)
select
  (select count(*) from phase4_invalid_categories),
  count(*),
  0,
  0
from updated;

with updated as (
  update public.transactions t
  set category_id = u.id
  from phase4_unknown_categories u
  where t.user_id = u.user_id
    and t.category_id is null
  returning t.id
)
update phase4_cleanup_summary
set null_category_transactions_reassigned = (select count(*) from updated);

with deleted as (
  delete from public.categories c
  using phase4_invalid_categories i
  where c.user_id = i.user_id
    and c.id = i.category_id
    and not exists (
      select 1
      from public.transactions t
      where t.user_id = c.user_id
        and t.category_id = c.id
    )
  returning c.id
)
update phase4_cleanup_summary
set invalid_categories_deleted = (select count(*) from deleted);

commit;

select * from phase4_cleanup_summary;
