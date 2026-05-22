-- Phase 4 category cleanup audit.
-- Read-only. Lists category rows that fail the current app/Edge validation
-- rules and would be reassigned to each user's Unknown category by the cleanup.

with invalid_categories as (
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
    )
),
invalid_transaction_counts as (
  select
    i.user_id,
    i.category_id,
    count(t.id) as transaction_count
  from invalid_categories i
  left join public.transactions t
    on t.user_id = i.user_id
   and t.category_id = i.category_id
  group by i.user_id, i.category_id
),
null_transaction_counts as (
  select
    t.user_id,
    count(t.id) as null_category_transaction_count
  from public.transactions t
  where t.category_id is null
  group by t.user_id
)
select
  i.user_id,
  i.category_id,
  i.category_name,
  i.normalized_name,
  i.reason,
  coalesce(tc.transaction_count, 0) as transaction_count,
  coalesce(ntc.null_category_transaction_count, 0) as user_null_category_transactions
from invalid_categories i
left join invalid_transaction_counts tc
  on tc.user_id = i.user_id
 and tc.category_id = i.category_id
left join null_transaction_counts ntc
  on ntc.user_id = i.user_id
order by i.user_id, i.reason, i.category_name;
