with active_users as (
  select user_id from public.accounts
  union
  select user_id from public.categories
  union
  select user_id from public.budgets
  union
  select user_id from public.transactions
  union
  select user_id from public.merchant_category_rules
)
insert into public.categories (user_id, name, type, normalized_name)
select
  active_users.user_id,
  'Miscellaneous',
  'expense',
  public.normalize_category_name('Miscellaneous')
from active_users
where public.normalize_category_name('Miscellaneous') is not null
on conflict (user_id, normalized_name) do nothing;

update public.transactions as transaction
set category_id = miscellaneous.id
from public.categories as unknown
join public.categories as miscellaneous
  on miscellaneous.user_id = unknown.user_id
 and miscellaneous.normalized_name = public.normalize_category_name('Miscellaneous')
where transaction.user_id = unknown.user_id
  and transaction.category_id = unknown.id
  and unknown.normalized_name in ('unknown', 'uncategorized', 'other');
