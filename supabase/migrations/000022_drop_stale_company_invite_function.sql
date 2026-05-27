-- The active schema can contain an old public.create_company_invite function
-- that was never captured by the checked-in migrations. It calls
-- gen_random_bytes(24) without a stable extension schema/search_path, which
-- makes `supabase db lint --local` fail. The mobile app and Rex backend do not
-- reference this function, so remove any stale overloads and keep the source
-- schema as the contract.
do $$
declare
  stale_function record;
begin
  for stale_function in
    select p.oid::regprocedure::text as signature
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'create_company_invite'
  loop
    execute format('drop function if exists %s', stale_function.signature);
  end loop;
end $$;
