alter table public.profiles
  add column if not exists preferred_locale text
  check (
    preferred_locale is null
    or preferred_locale ~ '^[a-z]{2}(-[A-Z]{2})?$'
  );

comment on column public.profiles.preferred_locale is
  'User app language tag such as en or es-MX. Synced from mobile LocaleController.';
