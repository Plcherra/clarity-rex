-- Remove PII from admin_users owner note (UUID remains the access key).
update public.admin_users
set
  note = 'Primary Clarity owner account',
  updated_at = now()
where user_id = 'c89fa61a-f67e-4454-a4a7-2775adc774c3';
