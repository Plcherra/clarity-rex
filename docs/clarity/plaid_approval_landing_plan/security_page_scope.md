# Clarity Security Page Scope

Status: File 06 Phase 1 security page scope approved for initial landing launch draft.

Purpose: define what the public `/security` page should explain before drafting data flow, access controls, encryption/storage, AI/voice vendor handling, deletion/disconnection, incident contact, and final security review.

The Security and Data Handling page should build trust with users and Plaid reviewers by explaining practical safeguards in plain language. It must describe current practices accurately and avoid unsupported security guarantees.

## Draft Page Identity

Route:

- `/security`

Page title:

- `Security & Data Handling`

Product name:

- `Clarity`

Assistant naming:

- `Rex` should be described as the AI assistant inside Clarity.

Last updated:

- `Last updated: [last updated date]`

Launch note:

- Replace the date placeholder with the final publication date before deployment.

## Audience

The page must be understandable to:

- Clarity users.
- Plaid reviewers.
- Future beta/waitlist users.
- People evaluating whether to connect a financial account.
- People looking for privacy, deletion, or security support.

The page should be clear enough for non-technical readers while still specific enough to support Plaid risk and security diligence.

## Page Role

The `/security` page should explain:

- What data Clarity may use to provide the product.
- How account connection starts with user authorization.
- How connected data flows into Clarity at a high level.
- How Clarity limits access to user data.
- How data is protected in transit and through hosted infrastructure.
- How AI, speech, and text-to-speech providers may fit into Rex features.
- How users can disconnect accounts or request deletion.
- How users can contact Clarity about security concerns.

The page should not:

- Replace the Privacy Policy.
- Replace the Terms of Service.
- Expose secrets, network internals, database details, tokens, keys, hostnames, or private infrastructure diagrams.
- Claim certifications, audits, or controls that have not been verified.
- Promise perfect security, perfect uptime, instant deletion, or real-time bank connectivity.

## Recommended Opening Summary

Preferred draft:

> Clarity is designed to use financial context only with user authorization and to explain how that context supports the product. This page summarizes Clarity's security and data-handling practices, including account connection, data flow, access controls, vendor processing, deletion paths, and support contact options.

Optional follow-up:

> This page is written for users and reviewers. It describes practical safeguards and product behavior without exposing private implementation details.

## Required Page Sections

The initial `/security` page should include these sections:

1. `Overview`
   - Plain-language summary of Clarity's security posture.
   - Clear statement that connected financial data is user-authorized.

2. `How data moves through Clarity`
   - High-level flow from user consent to Plaid connection, Clarity backend, mobile display, and Rex context.
   - No secrets or implementation internals.

3. `Access controls`
   - User authentication.
   - Limited team/admin access.
   - Purpose-bound support access.

4. `Encryption and storage`
   - HTTPS/TLS for data in transit.
   - Hosted infrastructure/database protections where accurate.
   - Vendor documentation verification before final publication.

5. `AI and voice processing`
   - Rex chat may process conversation and product context.
   - Voice features may process audio, transcripts, generated responses, and related metadata.
   - Cross-link to the Privacy Policy.

6. `Account disconnection and data deletion`
   - Users can disconnect connected accounts where supported.
   - Users can request deletion through the published deletion path.
   - Cross-link to `/data-deletion`.

7. `Security contact`
   - Clear support/security contact route.
   - No unrealistic response-time promise unless operationally supported.

8. `Review status`
   - Internal launch checklist only, not necessarily public copy.
   - Confirms unsupported claims and placeholders are removed before deployment.

## Plaid-Friendly Security Language

Use:

- `user-authorized account connection`
- `account and transaction context`
- `limited access practices`
- `secure transport`
- `hosted infrastructure protections`
- `disconnect accounts`
- `request deletion`
- `service providers`
- `Privacy Policy`
- `Data Deletion`

Avoid:

- `bank-grade`
- `military-grade`
- `Plaid-approved`
- `Plaid-certified`
- `guaranteed secure`
- `100% private`
- `unhackable`
- `always connected`
- `real-time balances`
- `we never process your data`
- `we never retain anything`

## Claims That Require Verification

Do not publish these without implementation, vendor, and legal verification:

- Specific encryption-at-rest details.
- Key-management details.
- SOC 2, ISO 27001, PCI, HIPAA, or similar certification claims.
- Penetration-test, audit, or vulnerability-management claims.
- Exact log retention periods.
- Exact deletion timeframes.
- Exact incident-response timelines.
- Zero-retention AI, speech, or TTS vendor claims.
- Claims that vendors never use, store, or retain data.

## Required Cross-Links

The Security page should link to:

- `/privacy`
- `/terms`
- `/data-deletion`
- `/contact`

The footer and relevant landing sections should link back to `/security`.

## Launch Placeholders To Resolve

Replace before public launch:

- `[last updated date]`
- `[support/contact email]`
- `[security contact email]` if separate.
- `[operator/legal entity]` if included on the page.
- Any vendor-specific security claim that has not been verified.
- Any exact support or deletion timeline that is not operationally guaranteed.

## Launch Review Questions

Before publishing the `/security` page, confirm:

- Does the page match the live product and backend configuration?
- Does it match the Privacy Policy and Terms of Service?
- Does it describe Plaid as a service provider, not an endorser or sponsor?
- Does it make user authorization clear?
- Does it avoid raw infrastructure details?
- Does it avoid unsupported certifications and guarantees?
- Does it give users a real contact path for security questions?
- Does it give Plaid reviewers enough information for risk and security diligence?

## Acceptance Checklist

- Covers data flow, access controls, encryption posture, vendors, deletion, and support.
- Uses user-friendly language.
- Avoids unsupported certifications or absolute security guarantees.
- Keeps technical details high-level and review-safe.
- Cross-links to Privacy, Terms, Data Deletion, and Contact.
- Leaves unresolved legal/operator/contact details clearly blocked before launch.
