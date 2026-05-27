# Supabase Schema Workflow Without Docker

This project does not require Docker for normal work. Supabase CLI commands that
need a local shadow database, such as `supabase db diff --local`, will fail when
Docker is not installed. Use this workflow instead.

## Normal Migration Flow

1. Create a numbered SQL migration in `supabase/migrations`.
2. Run `supabase db push` against the linked remote project.
3. Run a remote SQL smoke check in the Supabase SQL editor for the changed
   tables, policies, functions, or columns.
4. Run app tests that touch the changed behavior.

Run `supabase db push --dry-run` first when you only need to see which
migrations are pending without changing the remote project.

## Drift Check Flow

Use these checks when the app or CLI reports schema drift:

```sql
select
  n.nspname as schema,
  p.proname as function_name,
  p.oid::regprocedure::text as signature
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
order by p.proname;
```

```sql
select
  schemaname,
  tablename,
  policyname,
  cmd
from pg_policies
where schemaname = 'public'
order by tablename, policyname;
```

If a remote object is active but missing from migrations, add a migration that
either recreates it with stable dependencies or removes it when no app/runtime
code uses it.

## Remote Table Shape Check

Use this query when a Flutter/Supabase read says a column is missing:

```sql
select
  table_name,
  column_name,
  data_type,
  is_nullable
from information_schema.columns
where table_schema = 'public'
order by table_name, ordinal_position;
```

Use this query when RLS behavior is suspect:

```sql
select
  schemaname,
  tablename,
  rowsecurity
from pg_tables
where schemaname = 'public'
order by tablename;
```

## Current Drift Fix

Migration `000022_drop_stale_company_invite_function.sql` removes stale
`public.create_company_invite` overloads because no checked-in app, backend, or
function code references them and the stale body breaks schema linting.
