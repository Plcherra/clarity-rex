-- Profile photos.
--
-- The bucket is private. Nothing in Clarity shows one user's photo to another,
-- so a public URL would be a link that can leak and buy nothing; the app reads
-- through short-lived signed URLs instead.
--
-- Every policy below says the same thing: a user owns exactly the folder named
-- after their id, and nothing outside it. auth.uid() is wrapped in a subselect
-- so Postgres caches it per statement (lint 0003, auth_rls_initplan).

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars',
  'avatars',
  false,
  2097152,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Users read their own avatar" on storage.objects;
create policy "Users read their own avatar"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "Users upload their own avatar" on storage.objects;
create policy "Users upload their own avatar"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "Users replace their own avatar" on storage.objects;
create policy "Users replace their own avatar"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
)
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "Users remove their own avatar" on storage.objects;
create policy "Users remove their own avatar"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

-- Renamed because it holds an object path, never a URL: the only URL that works
-- is signed and expires within the hour, so storing one would store something
-- already dead. Safe to rename — nothing has ever written this column.
alter table public.profiles rename column avatar_url to avatar_path;

comment on column public.profiles.avatar_path is
  'Object path in the private avatars bucket, like <user id>/<epoch ms>.jpg.';
