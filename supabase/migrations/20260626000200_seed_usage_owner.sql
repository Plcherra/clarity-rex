-- Owner access for usage administration (Profile → Usage administration).
-- Safe to re-run: skips if this user is already an owner/admin.
insert into public.admin_users (user_id, role, note)
values (
  'c89fa61a-f67e-4454-a4a7-2775adc774c3',
  'owner',
  'Pedro Martins (plcherra@gmail.com) — primary Clarity owner'
)
on conflict (user_id) do update
set
  role = excluded.role,
  note = excluded.note,
  updated_at = now();
