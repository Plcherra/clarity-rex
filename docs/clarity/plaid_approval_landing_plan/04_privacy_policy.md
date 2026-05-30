# File 04 - Privacy Policy

Goal: create a product-specific privacy policy draft that is clear enough for users and reviewable for Plaid readiness.

## Phase 1 - Policy Scope

Goal: define who operates Clarity and what the policy covers.

Status: Complete. Privacy page identity, operator/contact placeholders, covered services, opening scope copy, required boundaries, cross-links, and legal review flags are captured in `privacy_policy_scope.md`.

Files to modify/create:
- `/privacy` page content

Acceptance Criteria:
- Identifies Clarity and operator/contact.
- Defines covered services: mobile app, public site, and Rex assistant.
- Includes last-updated date.

Risks & Mitigations:
- Risk: missing legal entity details.
- Mitigation: use available operator name and flag attorney review.

Effort: Small.

## Phase 2 - Data Categories

Goal: list data Clarity may collect.

Status: Complete. Account/profile data, financial account data, transactions, budgets, goals, Rex chat, voice/audio-derived content, memory/context, device/log data, support/contact data, derived data, sensitive-data boundaries, and Plaid-friendly wording are captured in `privacy_data_categories.md`.

Files to modify/create:
- Privacy data categories section

Acceptance Criteria:
- Covers account/profile, financial account data, transactions, balances, chat/voice content, device/log data, and support messages.
- Explains financial data comes from user-authorized connections.
- Avoids hidden categories.

Risks & Mitigations:
- Risk: forgetting voice/chat data.
- Mitigation: include Rex-specific data explicitly.

Effort: Medium.

## Phase 3 - Plaid Data Use

Goal: explain Plaid-connected data plainly.

Status: Complete. Plaid account-connection summary, authorization boundaries, possible connected data fields, Clarity use cases, Rex context language, disconnection/deletion wording, third-party policy link notes, and forbidden Plaid claims are captured in `privacy_plaid_data_use.md`.

Files to modify/create:
- Plaid data section

Acceptance Criteria:
- Explains users connect accounts through Plaid.
- Explains data may include account identifiers, balances, transactions, institution metadata, and related account data depending on permissions.
- Explains use: budgeting, categorization, spending analysis, and Rex context.

Risks & Mitigations:
- Risk: over-specific data list becomes inaccurate.
- Mitigation: phrase as "may include depending on permissions."

Effort: Medium.

## Phase 4 - Purpose Of Processing

Goal: explain why data is used.

Status: Complete. Product operation, financial organization, Rex personalization, voice processing, support/contact, security, analytics/product improvement, compliance, no-sale boundaries, and advertising boundaries are captured in `privacy_purpose_of_processing.md`.

Files to modify/create:
- Use of information section

Acceptance Criteria:
- Uses include app operation, personalization, transaction categorization, support, security, analytics, and compliance.
- States Clarity does not sell personal financial data.
- Does not imply unrelated ad targeting.

Risks & Mitigations:
- Risk: vague "improve services" language.
- Mitigation: pair general improvement with concrete examples.

Effort: Small.

## Phase 5 - Sharing And Vendors

Goal: disclose service providers and data processors.

Status: Complete. Vendor categories, known/likely provider examples, legal/safety sharing, user-directed sharing, business-transfer placeholder, no-sale boundary, and vendor review checklist are captured in `privacy_sharing_and_vendors.md`.

Files to modify/create:
- Sharing section

Acceptance Criteria:
- Mentions vendors used for infrastructure, auth/database, Plaid, AI, speech, text-to-speech, support/contact, analytics if used.
- Says vendors process data to provide services.
- Discloses legal/safety sharing scenarios.

Risks & Mitigations:
- Risk: vendor list changes.
- Mitigation: keep category-based with key vendor examples.

Effort: Medium.

## Phase 6 - Retention And Deletion

Goal: explain how long data is kept and how users can delete it.

Status: Complete. Account/profile, financial account, transaction, budget, goal, Rex chat, memory, voice, support/contact, log, backup retention, deletion workflow, data-deletion cross-link, and implementation questions are captured in `privacy_retention_and_deletion.md`.

Files to modify/create:
- Retention section
- `/data-deletion` page cross-link

Acceptance Criteria:
- Explains account, transaction, memory, chat, support, and log retention at a high level.
- Links to data deletion instructions.
- Explains disconnecting Plaid does not automatically erase all stored historical data unless requested, if that is product behavior.

Risks & Mitigations:
- Risk: retention promise conflicts with backend.
- Mitigation: align copy with actual deletion behavior before publishing.

Effort: Medium.

## Phase 7 - User Rights And Choices

Status: Complete - see `privacy_user_rights_and_choices.md`.

Goal: explain user controls.

Files to modify/create:
- Rights section

Acceptance Criteria:
- Covers access, correction, deletion, disconnecting accounts, support requests, and marketing opt-out if applicable.
- Provides contact email.
- Uses jurisdiction-neutral language while allowing future regional details.

Risks & Mitigations:
- Risk: making unsupported legal promises.
- Mitigation: keep rights language accurate and review before launch.

Effort: Small.

## Phase 8 - Privacy Review Gate

Status: Complete - see `privacy_review_gate.md`.

Goal: make the policy ready for product/legal review.

Files to modify/create:
- Privacy review checklist

Acceptance Criteria:
- No placeholders remain in the public policy draft, or the page remains clearly draft-only.
- All public data claims match implementation.
- Attorney review flag is visible before production.

Risks & Mitigations:
- Risk: treating draft as final legal advice.
- Mitigation: label as product-specific draft pending legal review.

Effort: Small.
