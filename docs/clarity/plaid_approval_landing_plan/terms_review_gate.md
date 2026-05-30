# Clarity Terms Review Gate

Status: File 05 Phase 8 terms review gate approved for initial landing launch draft.

## Purpose

This gate defines what must be true before Clarity's Terms of Service are published on the public landing site or submitted as supporting evidence for Plaid review.

The Terms are product-specific launch copy, not a substitute for attorney review. They must be reviewed against the live product, Privacy Policy, Security page, Data Deletion page, and public landing claims before production launch.

## Required Terms Draft Inputs

The Terms must be assembled from these approved planning contracts:

- `terms_scope.md`
- `terms_eligibility_accounts.md`
- `terms_financial_advice_boundary.md`
- `terms_ai_assistant_disclaimer.md`
- `terms_plaid_connection.md`
- `terms_acceptable_use.md`
- `terms_availability_limitation_changes.md`

## Launch Blockers

Do not publish the Terms if any of these are true:

- The Terms still contain placeholders such as `[operator/legal entity]`, `[support/contact email]`, `[effective date]`, `[last updated date]`, or unresolved TODO markers.
- The Terms claim a feature, support path, legal entity, product behavior, or account-control flow that does not exist.
- The Terms conflict with the Privacy Policy, Security page, Data Deletion page, FAQ, landing page, or app behavior.
- The Terms imply Clarity is a bank, broker, lender, investment advisor, financial advisor, tax advisor, accountant, law firm, or credit counseling service.
- The Terms imply Rex makes decisions, executes transactions, moves money, opens accounts, applies for credit, files taxes, or takes external actions for users.
- The Terms imply Plaid endorses, sponsors, certifies, approves, or provides Rex/AI features.
- The Terms promise continuous bank connectivity, real-time balances, complete transaction history, perfect categorization, perfect AI responses, guaranteed savings, guaranteed uptime, or guaranteed security.
- The Terms include a specific liability cap, governing law, arbitration, venue, or dispute-resolution clause that has not been reviewed.
- The Terms are presented as attorney-reviewed if that review has not happened.

## Product Claim Review

Before publication, verify every Terms claim against implementation:

- Clarity mobile app and public website behavior.
- Rex chat, memory, goals, voice, and conversation behavior.
- Account connection flow and whether Plaid is the only provider at launch.
- Whether account disconnect is self-serve, support-driven, or both.
- Whether account deletion and data deletion are self-serve, support-driven, or both.
- Whether public contact/support paths are live.
- Whether billing, subscriptions, or trial language exists.
- Whether beta, waitlist, or early-access language applies.
- Whether AI/voice provider processing is accurately cross-linked to Privacy and Security.

## Privacy And Security Alignment

The Terms must not contradict:

- `/privacy`
- `/security`
- `/data-deletion`
- `/contact`

Required alignment checks:

- Data categories in Privacy match Terms descriptions.
- Vendor/provider language in Privacy matches Terms third-party dependency language.
- Plaid consent language in Privacy and Terms uses the same basic meaning.
- Data deletion language does not conflict with account disconnection language.
- Voice, AI, and memory language is consistent across Terms, Privacy, Security, and FAQ.
- Support/contact email or route is the same across pages unless intentionally separated.

## Plaid-Friendly Terms Checklist

The Terms should clearly state:

- Account connection is user-authorized.
- Connected data availability depends on provider, institution, permissions, and product configuration.
- Users can disconnect accounts where supported.
- Users can request deletion through the published deletion path.
- Clarity uses connected data to provide product features, not to act as a bank or financial advisor.
- Rex uses Clarity context and does not connect directly to banks outside the user-authorized connection flow.

Avoid:

- `Plaid-approved`
- `Plaid-backed`
- `Plaid-certified`
- `partnered with Plaid`
- `bank-grade`
- `always connected`
- `real-time balances`
- `complete transaction history`
- `Rex connects to your bank`

## Required Public Links

The Terms page and footer must link to:

- `/privacy`
- `/security`
- `/data-deletion`
- `/contact`

The landing page footer must link to `/terms`.

## Placeholder Checklist

Replace before public launch:

- `[operator/legal entity]`
- `[support/contact email]`
- `[privacy/support email]` if referenced
- `[effective date]`
- `[last updated date]`
- `[mailing address]` if required by legal review
- Any placeholder billing/subscription language
- Any placeholder dispute-resolution or governing-law language

If a placeholder cannot be resolved, the Terms must remain draft-only.

## Legal Review Flags

Attorney review is required for:

- Operator/legal entity identity.
- Eligibility, minimum-age, personal-use, and geography language.
- Warranty disclaimers.
- Limitation of liability.
- Any specific liability cap.
- Governing law, venue, arbitration, dispute resolution, or class-action waiver clauses if added.
- Consumer-rights or regional compliance language.
- Billing, refund, cancellation, or subscription terms if added.
- Beta/early-access language.

## Final Acceptance Checklist

- All placeholders are replaced or the Terms remain draft-only.
- Terms align with landing page, FAQ, Privacy, Security, Data Deletion, and app behavior.
- Clarity is named as the product; Rex is described only as the assistant inside Clarity.
- Terms state Clarity is not a regulated financial/legal/tax/accounting/banking service.
- Rex/AI accuracy, review, and no-autonomous-action boundaries are clear.
- Plaid language is consent-based and avoids endorsement/approval claims.
- Acceptable use is user-readable and covers account, technical, harmful, financial, and AI misuse.
- Availability, changes, warranty, liability, and Terms-update drafts are visibly marked for legal review.
- Footer and legal cross-links are present and work on mobile and desktop.

