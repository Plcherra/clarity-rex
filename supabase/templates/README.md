# Supabase Auth Email Templates

Branded HTML templates for Supabase Auth (GoTrue). Paste these into the Supabase
Dashboard for the REX project (`oanwrprjpkfsyzxjlwer`).

## Apply in Dashboard

1. Open **Authentication → Email Templates**
2. For each template below, paste the HTML body and set the subject line
3. Save each template

| Template | Subject line | File |
|----------|--------------|------|
| Confirm signup | `{{ if eq .Data.language "es" }}Confirma tu cuenta Clarity{{ else }}Confirm your Clarity account{{ end }}` | `confirm-signup.html` |
| Reset password | `Reset your Clarity password` | `reset-password.html` |

The confirm-signup template is bilingual (English / Spanish). Sign-up passes
`language` in user metadata from the app locale (`en` or `es`).

Logo URL used in emails: `https://goclarity.app/clarity-mark-96.png`

Deploy the web app first so the logo and auth pages are live.
Confirmation emails should redirect to `https://goclarity.app/auth/confirmed/`
(add that URL and `https://goclarity.app/app/` to Supabase Auth → Redirect URLs).
The confirmed page forwards into the Flutter app.

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
