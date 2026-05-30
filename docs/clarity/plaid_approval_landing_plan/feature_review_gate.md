# Clarity Feature Review Gate

Status: File 03 Phase 8 feature review gate approved for initial landing launch.

Purpose: create the final approval checklist for all public feature copy and screenshot/product-proof assets before legal pages are finalized and before the landing site is implemented.

## Review Scope

This gate covers every public feature claim and feature visual from File 03:

- Public feature inventory.
- Dashboard feature section.
- Rex assistant feature section.
- Budget feature section.
- Privacy feature section.
- Screenshot/redaction policy.
- Visual consistency contract.

It also cross-checks against:

- Landing page structure.
- Hero value proposition.
- Plaid consent placement.
- Privacy Policy plan.
- Terms of Service plan.
- Security and Data Handling plan.

## Required Review Order

Use this order:

1. Confirm feature is in the approved public inventory.
2. Confirm the claim maps to implemented or launch-ready product behavior.
3. Confirm data/Plaid language is accurate and user-authorized.
4. Confirm legal/security pages can support the claim.
5. Confirm screenshot or visual is staged, synthetic, redacted, or non-sensitive.
6. Confirm mobile readability and visual consistency.
7. Confirm no regulated advice or autonomous money-management promise appears.
8. Approve, revise, or remove the claim.

## Claim Mapping Checklist

Every feature claim must map to one of these statuses:

- `Implemented and tested`
- `Implemented, needs final device check`
- `Supported by policy/security copy`
- `Planned but not public yet`
- `Remove before launch`

Only the first two statuses may appear as product feature claims in public landing copy.

`Supported by policy/security copy` may appear only for trust, compliance, data handling, deletion, or support claims. It must not be used to publish an unfinished product feature.

If a claim is `Planned but not public yet`, move it to internal roadmap notes.

If a claim is `Remove before launch`, remove it from page copy, screenshots, alt text, FAQ, and metadata.

## Feature Claim Acceptance

Dashboard claims are acceptable only if they:

- Explain income, spending, cash flow, budget progress, or transaction exploration.
- Avoid confusing account balance with monthly cash flow.
- Avoid exact forecasting.
- Avoid real-time balance promises unless implementation supports them.

Rex claims are acceptable only if they:

- Describe Rex as the assistant inside Clarity.
- Keep user judgment and control clear.
- Avoid claims of direct bank access outside Clarity's authorized data.
- Avoid financial, legal, tax, or investment advice positioning.

Budget claims are acceptable only if they:

- Show user-set targets.
- Explain progress depends on available transaction/categorization data.
- Avoid guaranteed savings or shame-based copy.

Privacy claims are acceptable only if they:

- Link to a specific policy/security/deletion/contact page.
- Avoid unsupported certifications.
- Avoid absolute guarantees.
- Explain user authorization and purpose-bound use.

## Screenshot And Asset Review

Every selected visual must pass:

- Synthetic/staged/redacted source confirmed.
- No personal financial data.
- No real account numbers, emails, tokens, raw logs, or private memories.
- No debug states, error states, import progress, retry banners, or raw backend labels.
- No Plaid Link or bank login screenshots unless later explicitly approved for compliance use.
- Mobile readability checked.
- Alt text drafted.
- Asset register entry prepared.

If any visual fails one item, do not patch it. Replace or recapture it.

## Policy Consistency Review

Before feature copy is considered final, compare it with:

- Privacy Policy.
- Terms of Service.
- Security and Data Handling.
- Data Deletion.
- Contact/Support.

Required consistency checks:

- Data categories match Privacy Policy.
- Account connection language matches Plaid/data consent copy.
- AI and voice language matches Privacy and Security pages.
- User control and deletion claims match implementation.
- No page promises support SLAs, certifications, or deletion timelines that are not supported.

## Plaid Review Readiness

Feature copy should help Plaid reviewers answer:

- What does Clarity do?
- Why does Clarity need account and transaction data?
- How does the user authorize access?
- What product features use the data?
- Where can a user read Privacy, Terms, Security, and Deletion details?

If a feature section does not support one of these answers, simplify or remove it.

## Review Notes Template

Create or use this template when actual copy/assets are selected:

```text
Feature:
Public claim:
Source file/section:
Implementation status:
Data used:
Policy/security page support:
Screenshot asset:
Redaction status:
Mobile check:
Decision: Approved / Revise / Remove
Reviewer:
Date:
Notes:
```

## Release Gate Decision

File 03 is ready to move into legal page drafting when:

- Every public feature is approved, revised, or removed.
- No unreviewed screenshots remain.
- Every feature/data claim has a matching Privacy/Security/Terms support path.
- No raw internal labels or backend concepts appear in user-facing copy.
- No claim implies Clarity is a bank, advisor, broker, lender, or autonomous money manager.

## Acceptance Checklist

- Every feature claim maps to implemented or launch-ready product behavior.
- Screenshots are redacted or staged.
- Plaid/data copy is consistent with Privacy and Security plans.
- Unsupported claims are removed or marked internal.
- File 03 is ready to hand off into File 04 Privacy Policy work.
