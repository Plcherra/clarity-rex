alter table public.account_statement_imports
  drop constraint if exists account_statement_imports_account_user_fk;

alter table public.account_statement_imports
  add constraint account_statement_imports_account_user_fk
  foreign key (user_id, account_id)
  references public.accounts(user_id, id)
  on delete cascade;

delete from public.account_statement_imports
where transaction_count <= 0;
