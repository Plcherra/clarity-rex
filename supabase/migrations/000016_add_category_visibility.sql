alter table public.categories
  add column if not exists hidden boolean not null default false;

create index if not exists categories_user_type_hidden_idx
  on public.categories(user_id, type, hidden);
