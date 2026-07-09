-- Lock financial_audit_events writes to service role only.
-- Authenticated clients retain SELECT for the audit UI.
-- Native and assistant writes go through rex-api with service-role insert.

revoke all on table public.financial_audit_events from anon, authenticated;
grant select on table public.financial_audit_events to authenticated;

drop policy if exists "Users can create their own financial audit events"
  on public.financial_audit_events;

drop policy if exists "Users can view their own financial audit events"
  on public.financial_audit_events;
create policy "Users can view their own financial audit events"
  on public.financial_audit_events
  for select
  to authenticated
  using ((select auth.uid()) = user_id);
