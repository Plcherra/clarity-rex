# File 03 - Features & Screenshots

Goal: show enough real product substance to build trust without exposing private data or overbuilding the web experience.

## Phase 1 - Feature Inventory

Goal: choose the features that should appear publicly.

Status: Complete. The approved v1 public feature set, user benefits, screenshot eligibility, copy boundaries, exclusions, and landing priority are captured in `public_feature_inventory.md`.

Files to modify/create:
- Feature content outline

Acceptance Criteria:
- Features include transactions, budgets, Rex chat, voice, memory, and goals only if polished enough.
- Each feature has one user benefit.
- Internal implementation details are excluded.

Risks & Mitigations:
- Risk: showcasing unfinished features.
- Mitigation: only show stable, testable features.

Effort: Small.

## Phase 2 - Screenshot Policy

Goal: define what screenshots are safe to publish.

Status: Complete. Screenshot source rules, forbidden visible data, demo data rules, asset register requirements, redaction checklist, review workflow, and Plaid-specific restrictions are captured in `screenshot_redaction_policy.md`.

Files to modify/create:
- Screenshot redaction checklist

Acceptance Criteria:
- Screenshots use synthetic or staged data.
- No real names, balances, account numbers, emails, or merchant history.
- Screenshot source date and test account are documented.

Risks & Mitigations:
- Risk: accidental privacy leak.
- Mitigation: review every image before commit.

Effort: Small.

## Phase 3 - Dashboard Feature Section

Goal: show Clarity's financial overview without confusing balance/cash-flow language.

Status: Complete. Dashboard section role, approved titles/copy, feature bullets, balance/cash-flow language rules, screenshot guidance, Plaid review alignment, and copy boundaries are captured in `dashboard_feature_section.md`.

Files to modify/create:
- Dashboard section copy/assets

Acceptance Criteria:
- Explains income, spending, budget progress, and transaction insight.
- Avoids promising exact financial forecasting.
- Uses clean screenshot or product mock.

Risks & Mitigations:
- Risk: old UI issues appear in screenshots.
- Mitigation: use current polished screens only.

Effort: Medium.

## Phase 4 - Rex Assistant Section

Goal: introduce Rex as the assistant inside Clarity.

Status: Complete. Rex feature positioning, approved titles/copy, feature bullets, data/privacy boundaries, screenshot guidance, and Plaid review alignment are captured in `rex_assistant_feature_section.md`.

Files to modify/create:
- Rex feature section

Acceptance Criteria:
- Explains chat, voice, and context-aware help.
- Does not claim Rex has direct bank access outside user-connected data.
- Includes privacy-aware language.

Risks & Mitigations:
- Risk: users think Rex is autonomous financial advisor.
- Mitigation: describe Rex as assistant/co-pilot.

Effort: Small.

## Phase 5 - Budget Feature Section

Goal: present budgeting as practical and user-controlled.

Status: Complete. Budget positioning, approved copy, feature bullets, data/control boundaries, screenshot guidance, Plaid review alignment, and tone rules are captured in `budget_feature_section.md`.

Files to modify/create:
- Budgets section

Acceptance Criteria:
- Shows monthly/weekly/custom budget concept.
- Explains budget tracking uses user transaction data.
- Avoids guilt-heavy or manipulative copy.

Risks & Mitigations:
- Risk: budget copy feels judgmental.
- Mitigation: use calm coaching tone.

Effort: Small.

## Phase 6 - Privacy Feature Section

Goal: make data handling a visible feature, not hidden legal text.

Files to modify/create:
- Privacy/trust feature cards

Acceptance Criteria:
- Cards cover consent, encryption/security practices, deletion, and support.
- Links to full policies.
- Uses plain language.

Risks & Mitigations:
- Risk: vague trust claims.
- Mitigation: tie each claim to a concrete page.

Effort: Small.

## Phase 7 - Visual Consistency

Goal: make screenshots and sections feel premium.

Files to modify/create:
- Feature card components
- Asset sizing rules

Acceptance Criteria:
- Assets share aspect ratio and visual treatment.
- Mobile layout avoids tiny unreadable screenshots.
- No oversized decorative cards.

Risks & Mitigations:
- Risk: screenshots make page heavy.
- Mitigation: optimize assets and lazy load below fold.

Effort: Medium.

## Phase 8 - Feature Review Gate

Goal: approve feature set before legal pages are finalized.

Files to modify/create:
- Feature review notes

Acceptance Criteria:
- Every feature claim maps to implemented product behavior.
- Screenshots are redacted.
- Plaid/data copy is consistent with privacy policy.

Risks & Mitigations:
- Risk: marketing and legal contradict each other.
- Mitigation: review feature copy alongside Privacy and Security pages.

Effort: Small.
