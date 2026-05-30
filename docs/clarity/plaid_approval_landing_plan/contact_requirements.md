# Clarity Contact Requirements

Status: File 07 Phase 1 contact requirements approved for initial landing launch draft.

Purpose: define the public contact paths Clarity needs before the landing site is used for Plaid review, beta access, support, privacy, deletion, or security inquiries.

This contract supports the `/contact` page, footer contact link, and any contact references from Privacy, Terms, Security, Data Deletion, and FAQ pages.

## Section Goal

The contact page should give users and Plaid reviewers a credible way to reach Clarity without turning the landing site into a full support portal.

It should make clear:

- How to request beta/waitlist access.
- How to ask for product support.
- How to make privacy or data deletion requests.
- How to report security concerns.
- What information users should not send through public forms or email.
- What response expectations are reasonable for an early-stage product.

The page should be plain, professional, and low-risk.

## Route And Page Identity

Route:

- `/contact`

Page title:

- `Contact Clarity`

Preferred short intro:

> Questions about Clarity, Rex, privacy, data deletion, security, or beta access? Contact us through the appropriate path below. Please do not send bank passwords, full account numbers, full card numbers, Social Security numbers, one-time login codes, API keys, or other sensitive secrets through this page.

Acceptable alternatives:

- `Get in touch`
- `Support and contact`
- `Contact and requests`

Avoid:

- `Talk to our bank team`
- `Plaid support`
- `Rex support center`
- `Submit financial documents`

## Required Contact Paths

The initial landing site should support these categories:

1. `Beta access`
   - For waitlist, early access, or launch questions.

2. `Product support`
   - For general questions about Clarity or Rex.

3. `Privacy request`
   - For questions about data use, retention, access, correction, or deletion.

4. `Data deletion`
   - For account/data deletion requests or follow-up.

5. `Security concern`
   - For suspected unauthorized access, vulnerability reports, or security questions.

6. `Other`
   - For anything that does not fit the above categories.

Do not create overly narrow categories that imply operational capabilities that do not exist yet.

## Required Public Information

The contact page must include:

- Published support email or form path.
- Reason/category selector or visible category guidance.
- Warning not to include sensitive credentials or secrets.
- Link to `/privacy`.
- Link to `/terms`.
- Link to `/security`.
- Link to `/data-deletion`.
- A general response expectation that does not promise instant response.

Recommended response expectation:

> We review incoming messages through the published support path. Response timing may depend on the request type, verification needs, and operational availability.

Do not promise:

- 24/7 support.
- Instant response.
- Guaranteed resolution.
- Legal, tax, investment, credit, or banking advice.
- That Clarity can fix every institution/Plaid connection issue.

## Sensitive Data Warning

The contact page and form should include this warning near the form:

> Please do not send bank passwords, full account numbers, full card numbers, Social Security numbers, one-time login codes, API keys, private keys, screenshots containing personal financial data, or other sensitive secrets.

If file upload is not needed, do not include file upload in the initial contact form.

If screenshots are ever allowed later, require redaction guidance before upload.

## Form Fields For General Contact

If using a form, recommended fields are:

- `Name`
- `Email`
- `Reason`
- `Message`
- `Consent checkbox`

Recommended consent checkbox:

> I understand Clarity may use the information I submit to respond to my request.

Optional anti-spam field/service:

- Honeypot field.
- Turnstile, reCAPTCHA, or hosting-provider spam protection.
- Rate limit if backed by a custom endpoint.

Avoid collecting:

- Bank username/password.
- Bank account numbers.
- Card numbers.
- Social Security number.
- Date of birth.
- Address unless needed for a verified legal request.
- Plaid tokens.
- API keys.
- Raw CSV files.
- Screenshots containing personal financial data.

## Footer Contact Link

The global footer must include:

- `Contact` linking to `/contact`.

Footer should also include:

- `Privacy`
- `Terms`
- `Security`
- `Data Deletion`

The footer contact link should appear on:

- Home page.
- Privacy Policy.
- Terms of Service.
- Security page.
- Data Deletion page.
- Waitlist/contact pages.

## Privacy And Deletion Routing

Privacy and deletion requests can start from `/contact`, but the user must also have a dedicated `/data-deletion` route.

Recommended routing:

- `/contact` includes `Privacy request` and `Data deletion` reason categories.
- `/data-deletion` explains deletion specifics and links back to `/contact` or uses the same form with `Data deletion` preselected.

Must convey:

- Identity verification may be required.
- Deletion may be subject to legal, security, fraud-prevention, backup, and operational limits.
- Disconnecting a connected account and deleting stored Clarity data are different actions.

## Security Report Routing

Security concerns may use the same support inbox initially, but the public copy should make the route clear.

Recommended copy:

> To report a security concern or suspected unauthorized account access, use `/contact` and choose `Security concern`, or email the published support/security address.

Do not publish a separate security address unless it is monitored.

Do not invite users to send:

- Exploit payloads containing live secrets.
- Data from accounts they are not authorized to access.
- Full logs containing personal financial data.
- Public disclosure links before coordination.

## Plaid-Friendly Wording

Use:

- `Contact Clarity`
- `beta access`
- `product support`
- `privacy request`
- `data deletion`
- `security concern`
- `published support path`
- `user-authorized account connection`
- `do not send sensitive credentials`

Avoid:

- `Plaid support`
- `bank support`
- `Rex connects your bank for you`
- `send bank screenshots`
- `send your login code`
- `instant deletion`
- `guaranteed response`
- `24/7 support`

## Launch Review Questions

Before publishing `/contact`, confirm:

- Is the support/contact path real and monitored?
- Do all footer links work on mobile and desktop?
- Are reason categories clear and not excessive?
- Does the page warn users not to submit sensitive credentials or secrets?
- Does the page link to Privacy, Terms, Security, and Data Deletion?
- Does any copy imply Plaid endorses, sponsors, or supports Clarity?
- Does the contact flow avoid collecting unnecessary sensitive data?
- Is spam protection or manual spam monitoring defined?
- Are success and error states planned before deployment?

## Acceptance Checklist

- Contact page includes a support email or form path.
- Contact page includes reason categories for beta access, support, privacy, data deletion, security, and other.
- Contact page avoids requesting sensitive financial details.
- Sensitive-data warning is visible before submission.
- Footer contact link is required globally.
- Privacy, Terms, Security, and Data Deletion links are included.
- Response expectations are professional and not overpromised.
- Plaid-friendly language is used throughout.
