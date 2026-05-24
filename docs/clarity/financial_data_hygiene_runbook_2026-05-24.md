# Financial Data Hygiene Runbook

Date: 2026-05-24

Use this once after applying all financial migrations through
`000019_financial_data_hygiene_backfill.sql`. The goal is not to mutate every
historical row. In this app, `transactions.financial_role = null` is valid:
the read model derives the role unless the user stores an explicit override.

## Required Migration Check

Run locally:

```bash
supabase db push
```

Expected pending migration:

```text
000019_financial_data_hygiene_backfill.sql
```

After it finishes, `supabase db push` should report the remote database is up to
date.

## Production Checks

Run these in Supabase SQL Editor.

### 1. Budget Rows Still Missing Category Identity

Expected: `0` rows or only budgets whose names are intentionally not category
budgets.

```sql
select
  b.id,
  b.user_id,
  b.name,
  b.category_key,
  b.category_id
from public.budgets b
where b.category_id is null
order by b.created_at desc;
```

### 2. Unknown Or Unassigned Transaction Categories

Expected: rows here are the manual review queue. They should be categorized,
ignored, or intentionally left for later.

```sql
select
  t.id,
  t.user_id,
  t.account_id,
  t.date,
  t.description,
  t.amount,
  t.type,
  c.name as category_name
from public.transactions t
left join public.categories c
  on c.user_id = t.user_id
 and c.id = t.category_id
where t.category_id is null
   or c.normalized_name in ('unknown', 'uncategorized', 'other')
order by t.date desc, t.created_at desc;
```

### 3. Category Type Mismatches

Expected: `0` rows.

```sql
select id, user_id, name, normalized_name, type
from public.categories
where (normalized_name in ('income payroll', 'income zelle received')
       and type <> 'income')
   or (normalized_name not in ('income payroll', 'income zelle received')
       and normalized_name in (
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
       and type <> 'expense');
```

### 4. Duplicate-Looking Categories

The normalized unique index should prevent exact duplicates. This query catches
legacy or near-duplicate display names that still need merge review.

```sql
select
  user_id,
  normalized_name,
  count(*) as category_count,
  array_agg(name order by name) as names
from public.categories
group by user_id, normalized_name
having count(*) > 1
order by category_count desc;
```

### 5. Merchant Rules That Need Review

Expected: disabled rules are okay if intentional. Rows with hidden categories
or weak confidence should be reviewed.

```sql
select
  r.id,
  r.user_id,
  r.merchant_key,
  r.merchant_display,
  r.match_type,
  r.confidence,
  r.disabled,
  c.name as category_name,
  c.hidden as category_hidden
from public.merchant_category_rules r
join public.categories c
  on c.user_id = r.user_id
 and c.id = r.category_id
where r.disabled = true
   or c.hidden = true
   or r.confidence < 0.8
order by r.updated_at desc;
```

### 6. Credit Card Payment Rows That Need Confirmation

These are not automatically backfilled. The app should keep unmatched card
payment rows in review until the opposite-side payment exists or the user
stores a manual role.

```sql
select
  t.id,
  t.user_id,
  t.account_id,
  t.date,
  t.description,
  t.amount,
  t.type,
  t.financial_role,
  c.name as category_name
from public.transactions t
join public.categories c
  on c.user_id = t.user_id
 and c.id = t.category_id
where c.normalized_name = 'credit card payment'
  and t.financial_role is null
order by t.date desc;
```

### 7. Accounts Without Statement Imports

Expected: newly created accounts may appear here. Imported accounts should have
statement imports so balances do not fall back to transaction sums.

```sql
select
  a.id,
  a.user_id,
  a.name,
  a.type,
  a.balance
from public.accounts a
left join public.account_statement_imports i
  on i.user_id = a.user_id
 and i.account_id = a.id
where i.import_id is null
order by a.created_at desc;
```

## Manual Cleanup Order

1. Open Budgets -> Manage categories -> merge duplicate custom categories.
2. Open the Dashboard review queue and clear unknown rows.
3. Disable or fix bad merchant rules before importing again.
4. Confirm credit card payment pairs or manually override the role.
5. Import one fresh statement per account so statement balances are available.
