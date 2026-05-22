create table if not exists public.merchant_category_rules (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  merchant_key text not null,
  merchant_display text,
  aliases text[] not null default '{}',
  category_id uuid not null,
  match_type text not null default 'normalized_exact',
  confidence numeric not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint merchant_category_rules_category_user_fk
    foreign key (user_id, category_id)
    references public.categories(user_id, id)
    on delete cascade,
  constraint merchant_category_rules_merchant_key_not_empty
    check (trim(merchant_key) <> ''),
  constraint merchant_category_rules_match_type_check
    check (match_type in ('normalized_exact', 'explicit_alias')),
  constraint merchant_category_rules_confidence_check
    check (confidence >= 0 and confidence <= 1)
);

create unique index if not exists merchant_category_rules_user_id_merchant_key_uidx
on public.merchant_category_rules(user_id, merchant_key);

create index if not exists merchant_category_rules_user_id_idx
on public.merchant_category_rules(user_id);

create index if not exists merchant_category_rules_user_id_category_id_idx
on public.merchant_category_rules(user_id, category_id);

create index if not exists merchant_category_rules_user_id_match_type_idx
on public.merchant_category_rules(user_id, match_type);

create index if not exists merchant_category_rules_aliases_gin_idx
on public.merchant_category_rules using gin(aliases);

drop trigger if exists merchant_category_rules_set_updated_at
on public.merchant_category_rules;
create trigger merchant_category_rules_set_updated_at
before update on public.merchant_category_rules
for each row
execute function public.set_updated_at();

alter table public.merchant_category_rules enable row level security;

drop policy if exists "Users can manage their own merchant category rules"
on public.merchant_category_rules;
create policy "Users can manage their own merchant category rules"
on public.merchant_category_rules
for all to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);
