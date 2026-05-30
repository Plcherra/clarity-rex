# Clarity Privacy Review Gate

Status: File 04 Phase 8 privacy review gate approved for initial landing launch draft.

## Purpose

This gate defines what must be true before Clarity's privacy policy is published on the public landing site or submitted as supporting evidence for Plaid review.

The privacy policy is product-specific launch copy, not a substitute for attorney review. It must be reviewed against the live implementation before production access or broad public launch.

## Required Privacy Draft Inputs

The privacy policy must be assembled from these approved planning contracts:

- `privacy_policy_scope.md`
- `privacy_data_categories.md`
- `privacy_plaid_data_use.md`
- `privacy_purpose_of_processing.md`
- `privacy_sharing_and_vendors.md`
- `privacy_retention_and_deletion.md`
- `privacy_user_rights_and_choices.md`

## Launch Blockers

Do not publish the privacy policy if any of these are true:

- The policy still contains placeholders such as `[privacy/support email]`, `[company/legal name]`, `[effective date]`, or unresolved TODO markers.
- The policy claims a feature, data control, security practice, or vendor integration that does not exist.
- The policy says Clarity stores less data than the app, backend, Supabase, Plaid, AI vendors, analytics, email tooling, or logs actually process.
- The policy describes Plaid as a bank, account provider, financial advisor, or decision maker.
- The policy promises instant deletion, guaranteed deletion from all backups, or deletion from every vendor system.
- The policy says Rex makes autonomous financial decisions or takes actions without user direction.
- The policy omits contact instructions for privacy, deletion, disconnection, or support requests.
- The policy is presented as attorney-reviewed if that review has not happened.

## Product Claim Review

Before publication, verify every public privacy claim against implementation:

- Linked financial account data only flows after user consent.
- Plaid data use is described as account connection and financial-data access, not credential storage.
- Rex assistant data use is described as personalized assistance, context, and memory where applicable.
- Voice data use matches current behavior and does not imply always-on listening.
- Waitlist/contact data use matches the actual waitlist/contact implementation.
- Data retention language matches the current deletion and support process.
- Disconnection language matches what the app or support can actually do.
- Vendor sharing language includes Plaid, Supabase or database hosting, AI model providers, speech-to-text, text-to-speech, hosting/infrastructure, email/contact tooling if used, and analytics if used.

## Required Public Links

The landing site footer and relevant pages must link to:

- `/privacy`
- `/terms`
- `/security`
- `/data-deletion`
- `/contact`

These links must work on desktop and mobile before the site is used for Plaid review.

## Placeholder Checklist

Replace before public launch:

- `[effective date]`
- `[privacy/support email]`
- `[company/legal name]` if a legal entity is used
- `[mailing address]` if required by legal review
- Any placeholder vendor list entries
- Any placeholder data deletion workflow text

If a placeholder cannot be resolved yet, the page must not be treated as final.

## Plaid-Friendly Language Checklist

Use language that clearly states:

- Clarity is a personal AI financial co-pilot.
- Rex is the assistant inside Clarity, not a separate financial institution.
- Users choose when to connect accounts.
- Clarity uses Plaid to help users connect financial accounts.
- Clarity does not sell personal financial data.
- Clarity does not store bank login credentials.
- Users can disconnect accounts and request deletion.

Avoid language that implies:

- Clarity is a bank.
- Clarity provides regulated investment, tax, credit, or legal advice.
- Plaid endorses Clarity.
- Rex can transact, move money, or make financial decisions on the user's behalf.

## Legal Review Flag

Add this internal status to the working copy until reviewed:

> Internal status: Product-specific privacy draft. Pending legal review before production launch.

This status does not need to be shown on the public page, but it must remain visible in source notes, launch checklists, or internal documentation until legal review is complete.

## Final Acceptance Checklist

- All placeholders are replaced or the page remains draft-only.
- Privacy data categories match live product behavior.
- Plaid data use is accurate, consent-based, and limited.
- Vendor sharing language is complete enough for the current stack.
- Retention and deletion language avoids unsupported promises.
- User rights and choices are clear and jurisdiction-neutral.
- Public footer links to privacy, terms, security, deletion, and contact pages.
- Attorney/legal review requirement is visible before production access.
- Clarity is named as the product; Rex is described only as the assistant inside Clarity.

