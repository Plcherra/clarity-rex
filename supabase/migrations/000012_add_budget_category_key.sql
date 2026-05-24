alter table public.budgets
  add column if not exists category_key text;

update public.budgets
set category_key = nullif(
  btrim(
    regexp_replace(
      regexp_replace(
        regexp_replace(
          replace(lower(trim(coalesce(name, ''))), '&', ' and '),
          '[^a-z0-9]+',
          ' ',
          'g'
        ),
        '(^|[[:space:]])and([[:space:]]|$)',
        ' ',
        'g'
      ),
      '[[:space:]]+',
      ' ',
      'g'
    )
  ),
  ''
)
where category_key is null or trim(category_key) = '';

alter table public.budgets
  drop constraint if exists budgets_category_key_not_empty;

alter table public.budgets
  add constraint budgets_category_key_not_empty
  check (category_key is null or trim(category_key) <> '');

create index if not exists budgets_user_period_start_category_key_idx
  on public.budgets(user_id, period, start_date, category_key);
