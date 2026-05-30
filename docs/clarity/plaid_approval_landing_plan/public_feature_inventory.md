# Clarity Public Feature Inventory

Status: File 03 Phase 1 feature inventory approved for initial landing launch.

Purpose: decide which Clarity product surfaces are safe and useful to show publicly for Plaid review and early-user trust.

## Feature Selection Rule

Only show features that are:

- Real in the current product.
- Stable enough for reviewer inspection.
- Explainable in plain language.
- Safe to show with synthetic or staged data.
- Directly related to Clarity's Plaid use case, trust story, or product value.

Do not show internal architecture, backend implementation, or debug details.

## Approved V1 Public Feature Set

### 1. Financial Overview

User benefit:

- See income, spending, cash flow, and pressure points in one place.

Public use:

- Primary feature section.
- Hero visual candidate.

Screenshot status:

- Approved if synthetic/staged data is used and the current UI is clean.

Copy boundaries:

- Do not promise forecasting accuracy.
- Do not imply Clarity is a financial advisor.

### 2. Transaction Organization

User benefit:

- Review transactions by month, category, row, account, and role.

Public use:

- Feature section or screenshot support.

Screenshot status:

- Approved only with synthetic merchants and balances.

Copy boundaries:

- Do not show real merchant history.
- Do not expose account identifiers.

### 3. Budgets

User benefit:

- Set monthly, weekly, or custom budgets and compare spending against targets.

Public use:

- Primary feature section.
- Screenshot candidate because current budget experience is polished and concrete.

Screenshot status:

- Approved with synthetic category names and amounts.

Copy boundaries:

- Avoid guilt-heavy language.
- Avoid guaranteed savings claims.

### 4. Rex Chat

User benefit:

- Ask Rex questions about money, goals, and saved context.

Public use:

- Primary feature section.
- Screenshot candidate if conversation content is staged and privacy-safe.

Screenshot status:

- Approved with staged conversation only.

Copy boundaries:

- Rex is the assistant inside Clarity, not the product.
- Do not claim Rex has direct bank access outside user-authorized Clarity context.
- Do not claim Rex gives regulated financial advice.

### 5. Rex Voice

User benefit:

- Talk to Rex hands-free when the user wants a voice-first assistant flow.

Public use:

- Secondary feature mention unless latest device testing confirms stable enough for screenshots.

Screenshot status:

- Conditional.

Copy boundaries:

- Do not overpromise call reliability.
- Do not imply Rex records continuously.
- Do not imply voice is required to use Clarity.

### 6. Memory

User benefit:

- Let Rex remember approved context so answers can feel more personal over time.

Public use:

- Secondary feature mention.

Screenshot status:

- Conditional; only show after pending/raw labels are polished and no sensitive memories appear.

Copy boundaries:

- Do not show private memories.
- Do not show raw labels like `long_term_memory` or entity internals.
- Emphasize user control and review.

### 7. Goals

User benefit:

- Keep plans, milestones, and money decisions connected to the assistant experience.

Public use:

- Secondary feature mention.

Screenshot status:

- Conditional; only show if the UI is polished and does not leak memory internals.

Copy boundaries:

- Do not show pending memory items as goals.
- Do not imply Clarity guarantees goal achievement.

## Excluded From V1 Public Feature Set

Do not showcase:

- Admin tools.
- Backend routing/brain internals.
- Debug logs.
- Raw memory extraction.
- Merchant rule internals.
- Import job diagnostics.
- Plaid Link screens.
- Bank login screens.
- Any unfinished web app concept.

## Feature Priority For Landing Page

Recommended public feature order:

1. Financial Overview.
2. Budgets.
3. Transaction Organization.
4. Rex Chat.
5. Trust/Data Controls.
6. Rex Voice, Memory, and Goals as supporting capabilities only if polished enough.

## Acceptance Checklist

- Feature list includes transactions, budgets, Rex chat, voice, memory, and goals with clear safety status.
- Every feature has one user benefit.
- Internal implementation details are excluded.
- Conditional features are marked clearly.
- Screenshot eligibility is documented before asset selection.
