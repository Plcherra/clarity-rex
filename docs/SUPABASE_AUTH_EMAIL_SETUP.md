# Supabase Auth Email Setup

Permanent production setup for Clarity sign-up confirmation, password reset,
and MFA security notices.

## Why this matters

Clarity requires working auth email for launch:

- New users must confirm email before first sign-in when **Confirm email** is on.
- MFA security notices use Resend through the `send-mfa-security-email` Edge Function.
- Broken SMTP blocks Plan 8 auth smoke and is a **P0 launch blocker**.

## Current production issue (2026-06-26)

REX Supabase auth logs show Gmail SMTP rejection:

```text
535 5.7.8 Username and Password not accepted (BadCredentials)
→ 500: Error sending confirmation email
```

The project has **custom SMTP pointed at Gmail with invalid credentials**.
MFA emails already use **Resend** in Edge Functions. Auth email should use the
same provider.

## One provider for launch: Resend

Clarity already depends on Resend for MFA security mail
(`supabase/functions/send-mfa-security-email`).

Use Resend for **Supabase Auth SMTP** too so sign-up confirmation and MFA mail
share one verified domain.

### 1. Resend domain setup

1. Open [Resend Dashboard](https://resend.com/domains).
2. Verify `goclarity.app` (DNS records on Cloudflare).
3. Create an API key with **Sending access**.
4. Recommended senders:
   - Auth mail: `Clarity <accounts@goclarity.app>`
   - MFA mail: `Clarity Security <security@goclarity.app>` (already used)

### 2. Supabase Auth SMTP (Dashboard)

Project: **REX** (`oanwrprjpkfsyzxjlwer`)

1. **Project Settings → Authentication → SMTP Settings**
2. Enable **Custom SMTP**
3. Set:

| Field | Value |
|-------|-------|
| Host | `smtp.resend.com` |
| Port | `465` (SSL) or `587` (TLS) |
| Username | `resend` (must be exactly this literal string) |
| Password | Your Resend API key (`re_...`) — not your Resend account password |
| Sender email | `accounts@goclarity.app` |
| Sender name | `Clarity` |

4. **Remove/disable the old Gmail SMTP credentials** (they are failing).

### 3. Supabase Auth URL configuration

1. **Authentication → URL Configuration**
2. **Site URL:** `https://goclarity.app`
3. **Redirect URLs:** add
   - `https://goclarity.app/auth/confirmed`

The mobile app sends this redirect on sign-up through `AuthConfig.emailRedirectUrl`.

### 4. Supabase Auth providers

1. **Authentication → Providers → Email**
2. Keep **Enable Email provider** on
3. Keep **Confirm email** on for launch
4. Turn **Confirm phone** off unless phone auth is in scope

### 5. Edge Function secrets (MFA mail)

From repo root, linked to the same Resend project:

```sh
supabase link --project-ref oanwrprjpkfsyzxjlwer
supabase secrets set RESEND_API_KEY=re_your_key
supabase secrets set SECURITY_EMAIL_FROM="Clarity Security <security@goclarity.app>"
supabase functions deploy send-mfa-security-email
```

### 6. Branded auth email templates (Dashboard)

Paste the HTML templates from `supabase/templates/` into **Authentication → Email Templates**:

| Template | Subject | File |
|----------|---------|------|
| Confirm signup | `Confirm your Clarity account` | `supabase/templates/confirm-signup.html` |
| Reset password | `Reset your Clarity password` | `supabase/templates/reset-password.html` |

See `supabase/templates/README.md` for details. Logo URL:
`https://goclarity.app/clarity-mark-96.png`

### 7. Deploy the email-confirmed landing page

The web app hosts the post-confirmation page users see after clicking the email link:

```sh
cd apps/web
PUBLIC_SITE_URL=https://goclarity.app npm run build
# deploy via your Cloudflare Pages flow
```

Page path: `https://goclarity.app/auth/confirmed`

### 8. Verify before launch

Run the verification script from repo root:

```sh
export SUPABASE_URL=https://oanwrprjpkfsyzxjlwer.supabase.co
export SUPABASE_ANON_KEY=your_anon_key
./scripts/verify_supabase_auth_email.sh
```

Expected: `PASS: signup confirmation email accepted by Supabase Auth`

Then manually:

1. Create a **new** test account in the mobile app.
2. Receive confirmation email within 2 minutes.
3. Open the link → lands on `https://goclarity.app/auth/confirmed`.
4. Sign in in the app.
5. Enable MFA → receive MFA security email.

### 9. Clean up failed sign-up attempts

Dashboard → **Authentication → Users**

Delete unconfirmed duplicate rows created while SMTP was broken (for example
retries on the same email). Keep your primary test account.

## Launch gate

Do **not** launch until all are true:

- [ ] `./scripts/verify_supabase_auth_email.sh` passes
- [ ] Real device sign-up + email confirm + sign-in passes
- [ ] MFA enable sends security email
- [ ] Supabase auth logs show no `Error sending confirmation email`

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `535 BadCredentials` in auth logs | Replace Gmail SMTP with Resend SMTP; username must be `resend` |
| SMTP saved but still failing | Username is not `resend`, or password is not the API key |
| Sign-up succeeds but no email | Check Resend domain verification and sender address |
| Link opens but auth fails | Add redirect URL in Supabase URL configuration |
| App shows email send error | Re-run verify script; check auth logs |
| Duplicate email, no mail | Delete unconfirmed user in dashboard or sign in instead |

## Related files

- Mobile redirect: `apps/mobile/lib/features/auth/application/auth_config.dart`
- Sign-up call: `apps/mobile/lib/features/auth/application/auth_service.dart`
- Email templates: `supabase/templates/confirm-signup.html`, `reset-password.html`
- Landing page: `apps/web/src/pages/auth/confirmed.astro`
- Auth layout: `apps/web/src/layouts/AuthLayout.astro`
- MFA mail function: `supabase/functions/send-mfa-security-email/index.ts`
- Launch smoke: `docs/CLARITY_BETA_SMOKE_RUNBOOK.md`
