alter table public.budgets
  add column if not exists category_id uuid references public.categories(id) on delete set null;

update public.budgets as budget
set category_id = category.id
from public.categories as category
where budget.category_id is null
  and budget.user_id = category.user_id
  and coalesce(nullif(trim(budget.category_key), ''), public.normalize_category_name(budget.name)) = category.normalized_name;

create index if not exists budgets_user_period_start_category_id_idx
  on public.budgets(user_id, period, start_date, category_id);
