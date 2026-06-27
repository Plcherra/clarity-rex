# Clarity Completion Master Plan

This folder turns the June 24 audit into execution plans for finishing Clarity as a complete MVP product.

## Target Outcome

Clarity should feel like one coherent app:

- Finance data is connected, current, and trusted.
- Rex uses the same financial truth the app shows.
- Chat, voice, memory, goals, and accountability share one simple Rex Brain path.
- The main UI paths are reachable, polished, and tested.
- Backend services are reliable enough to debug and operate.
- No hidden, orphaned, or misleading product surfaces remain.

## Plan Files

1. `01_PRODUCT_WIRING_PLAN.md` - close frontend/backend feature gaps and remove orphaned screens.
2. `02_FINANCE_AND_PLAID_PLAN.md` - finish finance, Plaid, CSV, budgets, transactions, and Rex finance truth.
3. `03_REX_MEMORY_AND_RECALL_PLAN.md` - finish saved memory, old chat recall, Knows, and truth labeling.
4. `04_GOALS_ACCOUNTABILITY_PLAN.md` - complete Goals, commitments, plans, milestones, and accountability UI.
5. `05_VOICE_AND_USAGE_PLAN.md` - choose the production voice path and complete usage tracking.
6. `06_UI_UX_COMPLETION_PLAN.md` - finish visual polish, navigation, accessibility, and empty/error states.
7. `07_BACKEND_INFRASTRUCTURE_PLAN.md` - reduce backend risk, simplify service organization, and harden readiness.
8. `08_QA_RELEASE_PLAN.md` - define the final verification, smoke, test, and launch checklist.
9. `09_CHARTS_USAGE_AND_FINANCE_VIZ_PLAN.md` - owner usage admin, voice usage charts, and finance visualizations (phased).

**Cross-cutting (brain trust):** [`docs/brain/REX_BRAIN_TRUST_RELIABILITY_PLAN.md`](../brain/REX_BRAIN_TRUST_RELIABILITY_PLAN.md) — P0/P1/P2/P3 brain trust, file splits, multi-user reliability. Execute alongside plans 03, 04, and 07. **Run P0 trust blockers before adding more goal/memory parser patches.**

## Priority Order

1. Product wiring and orphan cleanup.
2. Goals and accountability completion (includes brain trust P0 from `REX_BRAIN_TRUST_RELIABILITY_PLAN.md`).
3. Voice path consolidation.
4. Finance and Plaid hardening.
5. Rex memory and recall reliability.
6. UI/UX polish.
7. Backend organization cleanup.
8. Full QA and release pass.

## Completion Standard

A plan is complete only when:

- User-facing behavior is implemented or intentionally removed.
- Backend writes are confirmed before the UI or Rex claims success.
- Missing/degraded data is visible to the user.
- Tests or smoke checks cover the main path.
- Documentation reflects the actual production path.

## Score Target

Current audit score: 76/100.

Completion target:

- 85/100 after product wiring, Goals, voice consolidation, and key UI cleanup.
- 90/100 after backend service cleanup and full QA release pass.
