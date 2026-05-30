# Legal Review Status

Status: File 10 Phase 2 legal-review marker complete.

## Purpose

This document records the legal-review status for Clarity's public landing site before deployment and Plaid review package preparation.

It exists so the team does not accidentally treat product-authored Privacy, Terms, and Security copy as attorney-reviewed legal advice.

## Current Review Status

Public pages are product-reviewed and deployment-QA-ready.

They are not attorney-reviewed.

This applies to:

- Privacy Policy: `apps/web/src/pages/privacy.astro`
- Terms of Service: `apps/web/src/pages/terms.astro`
- Security and Data Handling: `apps/web/src/pages/security.astro`
- Data Deletion: `apps/web/src/pages/data-deletion.astro`
- Contact/support copy: `apps/web/src/pages/contact.astro`

## Launch Decision

Decision:

- It is acceptable to proceed with deployment preparation and Plaid questionnaire preparation using the current public pages.
- It is not acceptable to claim that the legal pages have been reviewed by an attorney.
- It is not acceptable to remove this review marker until legal review is actually completed or the owner intentionally accepts the risk.

Reason:

- Plaid review needs a public Privacy Policy, Terms, Security/Data Handling, Data Deletion, and Contact path.
- The current copy is conservative, product-specific, and avoids unsupported guarantees or endorsement claims.
- The current copy is still an early-stage launch draft and should receive attorney review before broad public launch or production-scale use.

## Attorney-Review Follow-Ups

Items to review with counsel when available:

- Operator/legal entity naming.
- Whether a mailing address is required.
- Minimum-age, geography, eligibility, and personal-use language.
- Privacy-rights language for applicable jurisdictions.
- Data retention, deletion, backup, and vendor-processing language.
- AI/Rex limitation language.
- Financial advice, tax, legal, accounting, credit, and investment-advice boundaries.
- Warranty disclaimer language.
- Limitation-of-liability language.
- Dispute resolution, governing law, venue, arbitration, or class-action terms if added.
- Incident/security notification language.
- Beta/waitlist and contact-form consent language.

## Security-Review Follow-Ups

Items to verify operationally before relying on them for security diligence:

- Current vendor list.
- Access-control practices.
- Authentication and user-scoping behavior.
- Backend logging and retention behavior.
- Backup and deletion behavior.
- AI model provider behavior.
- Speech-to-text and text-to-speech provider behavior.
- Contact/security report monitoring.
- FormSubmit destination activation and delivery behavior after deployment.

## Public Claim Boundaries

The public site must not claim:

- Attorney-reviewed legal pages.
- Plaid approval, endorsement, certification, sponsorship, or partnership.
- Bank-grade or military-grade security.
- Perfect security, perfect categorization, perfect AI, guaranteed outcomes, or guaranteed deletion.
- Real-time bank data or complete transaction history.
- That Rex can move money, open accounts, file taxes, apply for credit, or take financial actions for users.

## Current Public Copy Review

Checks completed before this marker:

- Placeholder legal/security pages were replaced.
- User-facing draft/TODO scan passed.
- Forbidden public-claim scan passed.
- Release build passed.
- NPM audit reported zero vulnerabilities.

## Owner Sign-Off Marker

Product owner sign-off status:

- Owner requested resolving Privacy, Terms, and Security placeholders before deployment planning.
- Owner is proceeding phase-by-phase toward deployment and manual testing.
- Owner has not stated that attorney review is complete.

Recorded launch posture:

- Proceed to File 10 Phase 3 Plaid questionnaire prep.
- Preserve legal-review follow-ups as open items.
- Do not submit to Plaid until production deployment and live FormSubmit testing are complete.

## Acceptance Decision

File 10 Phase 2 passes. Legal review status is explicit, attorney-review follow-ups are tracked, and the launch decision is intentional.
