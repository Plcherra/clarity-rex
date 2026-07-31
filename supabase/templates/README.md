# Supabase Auth Email Templates

Branded HTML templates for Supabase Auth (GoTrue). Paste these into the Supabase
Dashboard for the REX project (`oanwrprjpkfsyzxjlwer`).

## Apply in Dashboard

1. Open **Authentication → Email Templates**
2. For each template below, paste the HTML body and set the subject line
3. Save each template

| Template | Subject line | File |
|----------|--------------|------|
| Confirm signup | `Confirm your Clarity account` | `confirm-signup.html` |
| Reset password | `Reset your Clarity password` | `reset-password.html` |

Logo URL used in emails: `https://goclarity.app/clarity-mark-96.png`

Deploy the web app first so the logo and auth pages are live.
Confirmation emails should redirect to `https://goclarity.app/app/`
(add that URL to Supabase Auth → Redirect URLs). Older links to
`/auth/confirmed` still forward into the app.

## Variables

Supabase replaces these automatically:

- `{{ .ConfirmationURL }}` — the action link
- `{{ .Email }}` — recipient email
- `{{ .SiteURL }}` — project site URL
- `{{ .RedirectTo }}` — redirect after confirmation (from mobile sign-up)

Do not edit variable names.

## Preview

Send a test sign-up from the mobile app or run:

```sh
./scripts/verify_supabase_auth_email.sh
```

Then check inbox styling on phone and desktop mail clients.
