# Clarity Data Deletion Page Contract

Status: File 07 Phase 4 data deletion request page approved for initial landing launch draft.

Purpose: define the public `/data-deletion` page Clarity needs for users, privacy requests, account/data deletion requests, and Plaid review.

This contract aligns with:

- `privacy_retention_and_deletion.md`
- `privacy_user_rights_and_choices.md`
- `security_deletion_disconnection.md`
- `contact_requirements.md`
- `form_destination_plan.md`
- `terms_availability_limitation_changes.md`

## Page Goal

The Data Deletion page should give users a clear, public path to request deletion of Clarity account or product data.

It must explain:

- How to submit a deletion request.
- What types of data the request may cover.
- That identity verification may be required.
- That disconnecting a financial account and deleting stored Clarity data are different.
- That deletion may be subject to legal, security, fraud-prevention, backup, vendor, and technical limits.
- What information users should not send through public forms or email.

The page should be practical, calm, and honest. It should not sound evasive or overpromise capabilities that do not exist yet.

## Route And Page Identity

Route:

- `/data-deletion`

Page title:

- `Data Deletion`

Preferred intro:

> You can request deletion of your Clarity account or product data through the published contact path. Clarity may need to verify your identity and review the request scope before completing deletion.

Recommended follow-up:

> Disconnecting a connected financial account may stop future access through that connection, but it may not automatically delete historical data already stored in Clarity unless deletion is also requested.

Avoid titles:

- `Delete everything instantly`
- `Erase Plaid data`
- `Automatic bank deletion`
- `Instant account removal`

## Required Page Sections

The `/data-deletion` page should include:

1. `How to request deletion`
   - Link to `/contact`.
   - Explain selecting `Data deletion` as the reason if a form exists.
   - Provide the published support email if one is used.

2. `What your request can cover`
   - Account/profile data.
   - Connected or imported account/transaction data.
   - Budgets, categories, goals, plans, and progress.
   - Rex conversations, approved memory/context, and related metadata where supported.
   - Voice transcripts/generated responses/metadata where supported.
   - Support/contact/waitlist records where legally and operationally possible.

3. `Identity verification`
   - Explain verification may be required before action.
   - Ask users to contact Clarity from the email associated with their account if possible.

4. `Disconnecting vs deleting`
   - Explain that disconnection may stop future access, while deletion concerns stored Clarity data.

5. `Limits and retention`
   - Explain legal, security, fraud-prevention, backup, vendor, and technical constraints.

6. `What not to send`
   - Warn users not to send bank passwords, full account numbers, full card numbers, SSNs, one-time codes, API keys, secrets, screenshots, CSVs, or sensitive financial documents.

7. `Related links`
   - `/privacy`
   - `/terms`
   - `/security`
   - `/contact`

## Request Submission Path

Recommended path:

> To request deletion, use `/contact` and choose `Data deletion`, or email the published support address with the subject `Data deletion request`.

Recommended details to ask for:

- Name.
- Email associated with Clarity account.
- Short description of request scope.
- Whether the request is for account deletion, financial data deletion, Rex data deletion, waitlist/contact data deletion, or another category.

Do not ask users to send:

- Bank passwords.
- Full account numbers.
- Full card numbers.
- Social Security numbers.
- One-time login codes.
- Raw Plaid tokens.
- CSV files.
- Screenshots with personal financial data.
- Government ID through a public form unless a verified secure workflow exists.

## Request Scope Categories

The public page can describe request categories in plain language:

- `Delete my Clarity account`
- `Delete connected/imported financial data`
- `Delete Rex conversation or memory/context data`
- `Delete waitlist or contact data`
- `Ask a privacy question`

The form does not need to expose every internal category on day one, but the support workflow should be able to classify them.

## Identity Verification Copy

Recommended copy:

> Clarity may need to verify your identity before processing a deletion request. If possible, contact us from the email address associated with your Clarity account. We may ask for additional non-sensitive information needed to verify and complete the request.

Avoid:

- `No verification is required`
- `Anyone can delete an account`
- `We delete data based on any email request`
- `Send us your bank login to verify`

## Disconnection Vs Deletion Copy

Recommended copy:

> Disconnecting a financial account is different from deleting stored Clarity data. Disconnection may stop future access through that connection where supported. Historical information already stored in Clarity may remain until you request deletion or remove it through supported product controls.

This must remain unless implementation later guarantees automatic deletion of all historical data on disconnect.

## Limits And Retention Copy

Recommended copy:

> Some information may remain for a limited period in backups, logs, security records, support records, or systems where retention is needed for legal, fraud-prevention, security, dispute-resolution, or operational reasons. Some service providers may process or retain information according to their own terms, settings, privacy policies, or legal obligations.

Avoid:

- `Everything is deleted instantly`
- `All vendors delete everything immediately`
- `Deletion is guaranteed within 24 hours`
- `Backups are erased immediately`
- `No logs are retained`

## Confirmation Expectations

Recommended copy:

> After receiving a deletion request, Clarity may send a confirmation or follow-up through the published contact path. Response timing may depend on verification needs, request scope, operational availability, and legal or technical constraints.

Do not promise exact timelines until support operations can meet them.

## Plaid-Friendly Wording

Use:

- `request deletion`
- `published contact path`
- `identity verification`
- `connected or imported account and transaction data`
- `disconnecting is different from deleting`
- `historical data already stored in Clarity`
- `legal, security, backup, vendor, and technical constraints`

Avoid:

- `Plaid deletion page`
- `Plaid deletes your Clarity data`
- `erase every bank record`
- `instant deletion`
- `guaranteed deletion`
- `disconnect erases history`
- `delete all vendor records immediately`

## Implementation Notes

For first launch, `/data-deletion` can be a static page with:

- Clear explanatory copy.
- Link to `/contact` with deletion reason guidance.
- Published support email if available.
- Links to Privacy, Terms, Security, and Contact.

It does not need:

- Logged-in deletion dashboard.
- Automated self-serve account deletion.
- File upload.
- Identity document upload.
- Live ticket portal.

If a deletion request form is used later, it should follow `form_destination_plan.md`.

## Launch Review Questions

Before publishing `/data-deletion`, confirm:

- Is the contact path real and monitored?
- Does the page clearly explain how to request deletion?
- Does it explain identity verification may be required?
- Does it separate disconnection from deletion?
- Does it avoid instant deletion or complete vendor deletion promises?
- Does it warn users not to send sensitive credentials or secrets?
- Does it link to Privacy, Terms, Security, and Contact?
- Does the Privacy Policy link back to `/data-deletion`?
- Does the footer include a Data Deletion link?
- Does copy match actual product/support capability?

## Acceptance Checklist

- `/data-deletion` route and page purpose are defined.
- Page explains account/data deletion request path.
- Page provides contact or form path.
- Page explains identity verification may be required.
- Page separates account disconnection from stored-data deletion.
- Page describes legal, security, backup, vendor, and technical limits.
- Page warns users not to submit sensitive credentials or documents.
- Page cross-links to Privacy, Terms, Security, and Contact.
- Copy avoids unsupported automation, instant deletion, and Plaid endorsement claims.
