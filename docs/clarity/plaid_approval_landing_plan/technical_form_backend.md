# Clarity Landing Form Backend

Status: File 08 Phase 5 form backend approved for initial landing launch draft.

Purpose: define and implement the first reliable waitlist/contact form path for the static Clarity landing site without adding secrets, authenticated web app scope, or product database coupling.

## Decision

Use a hosted-form-provider-compatible static form for the initial launch.

Initial destination:

- `clarity.rex@gmail.com`

Initial implementation:

- `apps/web/src/components/PublicForm.astro`
- Home waitlist form in `apps/web/src/pages/index.astro`
- Contact form in `apps/web/src/pages/contact.astro`
- Success route in `apps/web/src/pages/form-success.astro`
- Error fallback route in `apps/web/src/pages/form-error.astro`

## Provider Position

The current form action uses a no-secret hosted form destination pattern and routes submissions to the monitored support inbox.

Before production launch, confirm:

- The provider destination is verified for `clarity.rex@gmail.com`.
- Test submissions arrive in the monitored inbox.
- The Privacy Policy discloses contact/waitlist form processing by service providers if applicable.
- The provider does not expose submissions publicly.

If the final deployment platform provides native form handling, the form component can be adapted without changing the public field contract.

## Fields Implemented

Waitlist form:

- `name`
- `email`
- `message`
- `consent`
- hidden `type=waitlist`
- hidden `source_page=home_waitlist`

Contact form:

- `name`
- `email`
- `type`
- `message`
- `consent`
- hidden `source_page=contact_page`

## Validation

Current validation:

- Required name.
- Required valid-looking email via `type=email`.
- Required reason on contact form.
- Required consent checkbox.
- Name max length 120.
- Email max length 254.
- Message max length 1000.

The form intentionally does not collect bank names, balances, credentials, account numbers, CSV files, screenshots, or Plaid tokens.

## Spam Protection

Current spam controls:

- Hosted provider spam handling where available.
- Honeypot field named `_honey`.
- Message length limits.
- Required fields.

Optional later controls:

- Cloudflare Turnstile.
- Deployment provider bot filtering.
- Rate-limited serverless endpoint.

Do not add heavy CAPTCHA until real abuse appears.

## Success And Error States

Success page:

- `/form-success`

Error fallback page:

- `/form-error`

Public copy follows `form_confirmation_copy.md`:

- No instant response promise.
- No beta approval promise.
- No deletion completion promise.
- No Plaid endorsement or approval claim.
- No raw provider/database errors.

## Security And Privacy Rules

- No secrets are committed.
- No form provider secret is used in client code.
- No production financial/app tables receive public landing submissions.
- Users are warned not to send sensitive financial details.
- The support email is public and intentionally used as the monitored intake path.

## Known Pre-Launch Checks

Before using the form for Plaid review:

- Submit a waitlist test.
- Submit a contact test.
- Confirm both arrive at `clarity.rex@gmail.com`.
- Confirm provider verification is complete.
- Confirm spam/honeypot behavior if provider supports it.
- Confirm Privacy Policy mentions form/contact data and service providers if needed.
- Confirm `PUBLIC_SITE_URL=https://rexpilot.com` or the final production domain before deployment.

## Acceptance Checklist

- Waitlist form validates fields.
- Contact form validates fields.
- Spam honeypot exists.
- Success state exists.
- Error fallback state exists.
- Public support destination is `clarity.rex@gmail.com`.
- No secrets are exposed client-side.
- No sensitive financial details are requested.
