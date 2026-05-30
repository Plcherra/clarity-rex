# Clarity Form Destination Plan

Status: File 07 Phase 3 form destination approved for initial landing launch draft.

Purpose: define where waitlist/contact submissions should go, how spam should be controlled, and what success/error behavior must exist before the public landing site is used for Plaid review.

This contract supports waitlist, contact, privacy, data deletion, and security inquiry flows.

## Section Goal

The first public forms should be boring, reliable, and privacy-conscious. They should collect only the fields approved in:

- `contact_requirements.md`
- `waitlist_form_scope.md`

The form destination should be easy to monitor and test. It should not require a full web app, user login, or complex support tooling.

## Recommended Launch Decision

Preferred launch path:

1. Use a simple hosted form provider or serverless form endpoint for the public landing site.
2. Deliver submissions to a monitored support inbox.
3. Store only minimal submission metadata if needed for reliability.
4. Add spam protection before launch.
5. Move to a Supabase-backed table only when the schema, RLS, retention, and internal review workflow are intentionally designed.

Acceptable alternate path:

1. Use Supabase for waitlist/contact submissions.
2. Create dedicated public-intake tables, not product tables.
3. Apply strict insert-only public access and private/admin read access.
4. Add rate limiting or bot protection at the edge/form layer.
5. Document retention and deletion handling before publication.

Do not use:

- Mobile app production tables directly.
- A public table with broad read access.
- A form that emails secrets to personal inboxes without monitoring.
- A raw endpoint that exposes stack traces or database errors.

## Submission Types

The destination must support these submission types:

- `waitlist`
- `beta_access`
- `product_support`
- `privacy_request`
- `data_deletion`
- `security_concern`
- `other`

The implementation may use one shared form endpoint with a `reason` field, or separate endpoints if that is simpler operationally.

## Minimal Data Shape

Recommended submission fields:

- `id`
- `created_at`
- `type`
- `name`
- `email`
- `message`
- `consent`
- `source_page`
- `status`
- `spam_signal`

Optional technical metadata:

- `user_agent`
- `referrer`
- `ip_hash` or provider-managed abuse signal if needed.

Avoid storing:

- Raw IP addresses unless needed and disclosed.
- Bank credentials.
- Account numbers.
- Card numbers.
- Social Security numbers.
- Plaid tokens.
- Uploaded files.
- Screenshots.
- CSV files.
- Full browser fingerprints.

## Supabase Table Option

If Supabase is used, recommended table names:

- `public_waitlist_submissions`
- `public_contact_submissions`

Required constraints:

- Public/anonymous users can insert only.
- Public/anonymous users cannot select, update, or delete submissions.
- Internal/admin service access is required for reads.
- Email and message fields have length limits.
- `consent` is required for waitlist submissions.
- `created_at` is server-generated.

Recommended statuses:

- `new`
- `reviewed`
- `responded`
- `closed`
- `spam`

Do not store public submissions in user financial tables or assistant memory tables.

## Hosted Form Provider Option

If using a form provider, confirm:

- It supports custom success/error states.
- It supports spam protection or integrates with one.
- It can route messages to the monitored support inbox.
- It does not require users to create accounts.
- It provides enough logging to confirm submissions were received.
- Its privacy behavior can be disclosed in the Privacy Policy if needed.

Do not use a provider if:

- It injects unrelated marketing or tracking.
- It stores more data than needed.
- It exposes submissions publicly.
- It cannot be monitored reliably.

## Spam Protection

Minimum acceptable spam controls:

- Honeypot field or provider spam filter.
- Basic rate limiting if custom endpoint is used.
- Server-side validation of required fields.
- Message length limits.
- Rejection or review flag for obvious bot submissions.

Optional additional controls:

- Cloudflare Turnstile.
- reCAPTCHA.
- Provider-managed bot detection.
- Domain allow/deny rules if abuse appears.

Do not add a heavy CAPTCHA unless needed. Keep mobile completion easy.

## Error And Success Behavior

Required success behavior:

- User sees confirmation without exposing backend details.
- Confirmation does not promise instant response or approval.
- Waitlist and support submissions can use different copy.

Required error behavior:

- User sees a helpful retry message.
- User can use `/contact` or published support email if the form fails.
- Raw database/API/provider errors are never shown.
- Client and server validation messages are clear.

This must align with:

- `waitlist_form_scope.md`
- `contact_requirements.md`
- `form_confirmation_copy.md`

## Logging And Monitoring

Before launch, define:

- Who receives submissions.
- Where submissions are visible.
- How failures are noticed.
- How spam is handled.
- How privacy/deletion/security requests are flagged.
- How test submissions are distinguished from real submissions.

Recommended:

- Send form submission notifications to a monitored support inbox.
- Keep an internal checklist or lightweight tracker for privacy/deletion/security requests.
- Log submission failures without storing sensitive message bodies in public logs.

## Privacy And Retention Alignment

The form destination must align with:

- `privacy_data_categories.md`
- `privacy_purpose_of_processing.md`
- `privacy_retention_and_deletion.md`
- `privacy_sharing_and_vendors.md`
- `privacy_user_rights_and_choices.md`

Public Privacy Policy should disclose:

- Contact/waitlist data may be collected.
- It is used to respond, operate the service, manage beta interest, and handle requests.
- Service providers may process submissions.
- Users can contact Clarity about privacy or deletion.

## Test Submission Requirements

Before launch, test:

- Valid waitlist submission.
- Valid contact/support submission.
- Missing required email.
- Invalid email.
- Missing consent for waitlist.
- Overlong message.
- Honeypot/spam behavior if available.
- Destination notification delivered.
- Success state displayed.
- Error state displayed or simulated.
- No sensitive details are requested.

## Plaid-Friendly Wording

Use:

- `monitored support path`
- `public intake form`
- `waitlist submission`
- `contact submission`
- `spam protection`
- `minimal data collection`
- `Privacy Policy`

Avoid:

- `Send us your bank details`
- `Upload your financial data`
- `Plaid form`
- `Plaid-approved signup`
- `Instant beta approval`
- `Guaranteed response`
- `No data retained`
- `Anonymous financial analysis`

## Launch Review Questions

Before publishing forms, confirm:

- Is the submission destination selected and documented?
- Is spam protection active?
- Are required fields validated client-side and server-side/provider-side?
- Are success and error states defined?
- Are submissions delivered to a monitored place?
- Does the Privacy Policy mention contact/waitlist submissions and service providers where needed?
- Are sensitive financial fields excluded?
- Are public users prevented from reading submissions if using a database?
- Has at least one test submission succeeded after deployment?

## Acceptance Checklist

- Submission destination is defined.
- Spam protection is defined.
- Success and error states are defined.
- Waitlist/contact fields match approved scope.
- Public submissions do not go into financial or assistant memory tables.
- Privacy Policy alignment is identified.
- Test submission plan exists.
- No backend internals or raw errors are exposed to users.
