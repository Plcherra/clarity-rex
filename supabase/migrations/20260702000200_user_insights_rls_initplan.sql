-- Remediate auth_rls_initplan (lint 0003) for user_insights policies.

drop policy if exists "Users can read their own insights" on public.user_insights;
create policy "Users can read their own insights" on public.user_insights
for select to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "Users can insert their own insights" on public.user_insights;
create policy "Users can insert their own insights" on public.user_insights
for insert to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update their own insights" on public.user_insights;
create policy "Users can update their own insights" on public.user_insights
for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);
