create or replace function public.normalize_category_name(input text)
returns text
language sql
immutable
as $$
  select nullif(
    regexp_replace(
      regexp_replace(
        regexp_replace(
          replace(lower(trim(coalesce(input, ''))), '&', ' and '),
          '[^a-z0-9]+',
          ' ',
          'g'
        ),
        '\mand\M',
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

do $$
declare
  duplicate_group record;
  loser record;
begin
  for duplicate_group in
    select
      user_id,
      public.normalize_category_name(name) as normalized_name,
      array_agg(id order by created_at, id) as category_ids
    from public.categories
    group by user_id, public.normalize_category_name(name)
    having count(*) > 1
  loop
    for loser in
      select id
      from unnest(duplicate_group.category_ids) with ordinality as category(id, ordinality)
      where ordinality > 1
    loop
      update public.transactions
      set category_id = duplicate_group.category_ids[1]
      where user_id = duplicate_group.user_id
        and category_id = loser.id;

      update public.budgets
      set
        category_id = duplicate_group.category_ids[1],
        category_key = duplicate_group.normalized_name
      where user_id = duplicate_group.user_id
        and category_id = loser.id;

      update public.merchant_category_rules
      set category_id = duplicate_group.category_ids[1]
      where user_id = duplicate_group.user_id
        and category_id = loser.id;

      delete from public.categories
      where user_id = duplicate_group.user_id
        and id = loser.id;
    end loop;
  end loop;
end $$;

update public.categories
set normalized_name = public.normalize_category_name(name)
where normalized_name is distinct from public.normalize_category_name(name);

update public.budgets
set category_key = public.normalize_category_name(name)
where category_id is null
  and public.normalize_category_name(name) is not null
  and category_key is distinct from public.normalize_category_name(name);

update public.budgets as budget
set category_key = category.normalized_name
from public.categories as category
where budget.user_id = category.user_id
  and budget.category_id = category.id
  and budget.category_key is distinct from category.normalized_name;
