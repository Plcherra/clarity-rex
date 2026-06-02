alter table public.memory_confirmations enable row level security;

drop policy if exists "Users can manage their own memory confirmations"
  on public.memory_confirmations;
create policy "Users can manage their own memory confirmations"
on public.memory_confirmations
for all to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

comment on table public.memory_confirmations is
  'Explicit user-scoped Rex memory confirmations. Rows are only visible and mutable by the owning authenticated user.';
