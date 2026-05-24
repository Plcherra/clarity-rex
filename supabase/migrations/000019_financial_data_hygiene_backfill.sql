with active_users as (
  select id as user_id from public.profiles
  union
  select user_id from public.accounts
  union
  select user_id from public.categories
  union
  select user_id from public.budgets
  union
  select user_id from public.transactions
  union
  select user_id from public.merchant_category_rules
),
canonical_categories(name, type) as (
  values
    ('Coffee / Quick Food', 'expense'),
    ('Credit Card Payment', 'expense'),
    ('Cash Withdrawal', 'expense'),
    ('Food & Drink', 'expense'),
    ('Grocery / Supermarket', 'expense'),
    ('Housing', 'expense'),
    ('Income / Payroll', 'income'),
    ('Income / Zelle Received', 'income'),
    ('Pharmacy / Health', 'expense'),
    ('Shoes / Clothing', 'expense'),
    ('Shopping', 'expense'),
    ('Subscriptions', 'expense'),
    ('Transfer Out', 'expense'),
    ('Transportation', 'expense'),
    ('Unknown', 'expense'),
    ('Ignored', 'expense')
)
insert into public.categories (user_id, name, type, normalized_name)
select
  active_users.user_id,
  canonical_categories.name,
  canonical_categories.type,
  public.normalize_category_name(canonical_categories.name)
from active_users
cross join canonical_categories
where active_users.user_id is not null
  and public.normalize_category_name(canonical_categories.name) is not null
on conflict (user_id, normalized_name) do nothing;

update public.categories
set type = 'income'
where normalized_name in ('income payroll', 'income zelle received')
  and type <> 'income';

update public.categories
set type = 'expense'
where normalized_name in (
    'coffee quick food',
    'credit card payment',
    'cash withdrawal',
    'food drink',
    'grocery supermarket',
    'housing',
    'pharmacy health',
    'shoes clothing',
    'shopping',
    'subscriptions',
    'transfer out',
    'transportation',
    'unknown',
    'ignored'
  )
  and type <> 'expense';

update public.budgets
set category_key = public.normalize_category_name(name)
where (category_key is null or trim(category_key) = '')
  and public.normalize_category_name(name) is not null;

update public.budgets as budget
set category_id = category.id
from public.categories as category
where budget.category_id is null
  and budget.user_id = category.user_id
  and coalesce(
    nullif(trim(budget.category_key), ''),
    public.normalize_category_name(budget.name)
  ) = category.normalized_name;
