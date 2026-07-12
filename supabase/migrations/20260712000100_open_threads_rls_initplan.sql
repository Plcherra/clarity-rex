-- Remediate auth_rls_initplan (lint 0003) for open_threads policies.
-- Wrap auth.uid() so Postgres can cache the initplan result per statement.

drop policy if exists "Users can manage their own open threads" on public.open_threads;
create policy "Users can manage their own open threads"
on public.open_threads
for all
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);
