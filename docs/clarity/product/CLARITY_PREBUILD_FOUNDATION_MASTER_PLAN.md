#1 Prebuild Foundation

Status: Complete

Last updated: June 6, 2026

## Purpose

Prepare Clarity for the full rebuild before touching product surfaces. This plan removes ambiguity around product identity, shared read models, design tokens, multi-user boundaries, and execution gates.

## Core Outcome

By the end of this plan:

- Clarity has one product vocabulary.
- Rex is only the conversational assistant name, not a competing app label.
- Shared read models are defined before Plaid, Assistant, Dashboard, Budgets, and Accounts are rebuilt.
- Every later plan has clear test, line-count, and privacy gates.

## Non-Goals

- Do not implement Plaid.
- Do not redesign UI screens.
- Do not change runtime behavior except small naming or cleanup needed to remove ambiguity.

## Current State

| Area | Current State | Risk |
| --- | --- | --- |
| Product identity | Clarity, Rex, Assistant, and finance labels overlap. | Users can think the app is multiple products. |
| Data truth | Screens and Assistant can read different context. | Trust breaks when Assistant cannot see visible data. |
| UI foundation | Assistant has dark tokens; app shell still has separate styling. | Modernization becomes duplicated. |
| Execution gates | Release checks are end-loaded. | Cleanup happens too late. |

## Target State

| Area | Target State | Benefit |
| --- | --- | --- |
| Identity | Clarity is the app; Rex is a voice/personality inside Assistant. | Clear product story. |
| Data | Shared read models define what Clarity knows. | Assistant and screens stay aligned. |
| Design | App-wide token contract exists before UI rebuild. | Consistent dark/minimal UI. |
| Gates | Each subsystem carries its own test and cleanup requirements. | Less late-stage mess. |

## Master Plan Execution Order

This plan set should be executed in this order:

1. `CLARITY_PREBUILD_FOUNDATION_MASTER_PLAN.md`
2. `CLARITY_USAGE_TRACKING_SIMPLIFIED_PLAN.md`
3. `PLAID_BACKEND_CORE_MASTER_PLAN.md`
4. `PLAID_MOBILE_AND_ACCOUNT_CONNECTION_MASTER_PLAN.md`
5. `CLARITY_DESIGN_SYSTEM_MASTER_PLAN.md`
6. `CLARITY_UNIFIED_PRODUCT_SHELL_MASTER_PLAN.md`
7. `CLARITY_FINANCIAL_EXPERIENCE_MASTER_PLAN.md`
8. `CLARITY_ASSISTANT_INTELLIGENCE_MASTER_PLAN.md`
9. `CLARITY_RELEASE_VALIDATION_MASTER_PLAN.md`

Usage tracking stays early because later Plaid, voice, Assistant, and UI work need provider usage and voice-minute visibility. The active usage plan is the simplified four-phase plan: simple events, real provider tracking, daily voice summary, and user/owner views. Release validation stays last and should only verify completed subsystem work, not absorb unfinished cleanup.

## Phase 1 - Current Architecture Snapshot

Goal: Create a current-state map of the mobile, backend, Supabase, Plaid, Assistant, CSV, and usage-tracking entry points.

Files to change:

- `docs/clarity/product/CLARITY_ARCHITECTURE_SNAPSHOT.md`
- `docs/clarity/screen_data_map.md`

Steps:

1. Map each top-level mobile feature and the services it calls.
2. Map backend routes and service ownership.
3. Map Supabase tables used by user data, financial data, Assistant data, and audit data.
4. Identify code paths that still describe CSV as the primary ingestion method.

Done looks like:

- The team can see the current system in one document.
- Later plans can reference this map instead of rediscovering ownership.

Acceptance criteria:

- [x] Snapshot lists mobile surfaces, backend routes, Supabase tables, and major service owners.
- [x] Snapshot marks Plaid, CSV, Assistant, usage, and design-system boundaries.
- [x] No implementation changes are made in this phase.

## Phase 2 - One-App Naming Rules

Goal: Define Clarity product language before UI and backend labels are changed.

Files to change:

- `docs/clarity/product/CLARITY_PRODUCT_VOCABULARY.md`

Steps:

1. Define allowed product labels: Clarity, Assistant, Rex, connected accounts, activity, budgets, goals, what Clarity knows.
2. Define banned labels in UI: pending memory, Rex app, memory candidates, backend review terminology.
3. Define where Rex may appear: conversational assistant copy only.
4. Add scan patterns for future regression checks.

Done looks like:

- Copy decisions stop being ad hoc.
- The app reads as one product.

Acceptance criteria:

- [x] Vocabulary doc exists.
- [x] Rex is explicitly limited to assistant personality/voice context.
- [x] The doc includes a search checklist for banned terms.

## Phase 3 - Aggressively Remove Remaining Rex/Product Split Assumptions

Goal: Remove or explicitly assign every remaining code/doc surface that implies Rex is a separate app or product. Rex may remain as the assistant's conversational name only.

Files to change:

- `docs/clarity/product/CLARITY_REX_LABEL_CLEANUP_LEDGER.md`
- `docs/clarity/product/CLARITY_PRODUCT_VOCABULARY.md`
- User-facing mobile copy where the fix is small and safe

Steps:

1. Search mobile, backend, docs, and tests for user-facing Rex-as-product labels.
2. Separate allowed conversational labels from product-shell violations.
3. Immediately clean obvious user-facing copy drift when it is small and isolated.
4. Record deeper implementation/file rename work with owning follow-up plan.
5. Remove old pending/review memory terminology from user-facing copy if it appears during the scan.
6. Do not rename deep implementation files unless the label leaks to users or blocks a later plan.

Done looks like:

- The product shell no longer reads like "Clarity + Rex" as two products.
- Any remaining implementation-level Rex naming is intentionally allowed or assigned to a specific later phase.

Acceptance criteria:

- [x] Ledger lists all active product-shell violations.
- [x] Allowed Rex conversational usage is documented.
- [x] Each violation has an owning plan file and phase.
- [x] No active user-facing copy uses Rex as an app/product label.
- [x] No active user-facing copy uses pending/review/candidate memory terminology.

## Phase 4 - Define Shared Clarity Read Models

Goal: Define the common data snapshots that screens and Assistant must both use.

Files to change:

- `docs/clarity/product/CLARITY_SHARED_READ_MODELS.md`

Steps:

1. Define user information read model.
2. Define connected institutions/accounts read model.
3. Define transaction/activity read model.
4. Define budgets/goals/commitments read model.
5. Define Assistant context snapshots from those same models.

Done looks like:

- Assistant truth and screen truth have one contract.

Acceptance criteria:

- [x] Read model doc includes ownership, fields, freshness expectations, and privacy boundaries.
- [x] Assistant context is explicitly derived from shared read models.
- [x] No read model contains Plaid access tokens or private telemetry content.

## Phase 5 - Define App-Wide Design Token Contract

Goal: Lock the minimal dark Clarity design direction before screen redesign.

Files to change:

- `docs/clarity/product/CLARITY_DESIGN_TOKEN_CONTRACT.md`

Steps:

1. Define app-wide near-black base colors inspired by the logo.
2. Define restrained teal accent usage.
3. Define financial green/red usage only for money states.
4. Define typography, spacing, radius, border, and elevation rules.
5. Define what must be removed: heavy borders, oversized pills, olive/yellow dominance, Rex-only token drift.

Done looks like:

- UI phases have a hard visual target.

Acceptance criteria:

- [x] Contract includes token names and usage rules.
- [x] Contract explicitly bans separate Rex-only app theming.
- [x] Contract includes accessibility contrast targets.

## Phase 6 - Define Multi-User Data Boundaries

Goal: Define user isolation rules before Plaid and usage tracking are implemented.

Files to change:

- `docs/clarity/product/CLARITY_MULTI_USER_DATA_BOUNDARY.md`

Steps:

1. Define which tables must be scoped by `user_id`.
2. Define which writes require backend/service-role authority.
3. Define which data users may read directly through Supabase.
4. Define admin/internal-only usage access.
5. Define cross-user test scenarios.

Done looks like:

- Multi-user safety is a design input, not a post-release patch.

Acceptance criteria:

- [x] Boundary doc covers Plaid, accounts, transactions, budgets, Assistant data, usage tracking, and profile data.
- [x] Cross-user test scenarios are listed.
- [x] Service-role-only operations are identified.

## Phase 7 - Define Test And Line-Count Gates

Goal: Create execution guardrails for every later subsystem.

Files to change:

- `docs/clarity/product/CLARITY_EXECUTION_GATES.md`
- `docs/clarity/release_checklists/FILE_SIZE_EXCEPTION_LEDGER.md`

Steps:

1. Define default 500-line file limit and exception process.
2. Define focused backend, mobile, and manual tests required for each subsystem.
3. Define screenshot QA requirements for UI phases.
4. Define security/privacy checks required for Plaid and usage tracking.

Done looks like:

- Every plan can point to the same execution gate.

Acceptance criteria:

- [x] Execution gate doc exists.
- [x] Gate includes backend, Flutter, screenshot, privacy, and RLS requirements.
- [x] Existing exception ledger is referenced instead of duplicated.

## Phase 8 - Prebuild Readiness Audit

Goal: Confirm the rebuild can start without foundational ambiguity.

Files to change:

- `docs/clarity/product/CLARITY_PREBUILD_READINESS_AUDIT.md`

Steps:

1. Verify all foundation docs exist.
2. Verify the nine-plan structure is current.
3. Verify old broad plans are removed or marked superseded.
4. Verify remaining unknowns are assigned to a subsystem plan.

Done looks like:

- The project is ready to execute Plaid, usage, UI, product shell, Assistant, and release plans in order.

Acceptance criteria:

- [x] Audit lists ready/not-ready status for each subsystem.
- [x] No unowned critical gap remains.
- [x] The next executable plan is identified.

## Verification Commands

```bash
rg -n "Rex app|pending memory|memory candidate|review session|CSV-first|csv-first" docs apps/mobile/lib services/rex-api
find docs/clarity/product docs/clarity/plaid -name '*MASTER_PLAN.md' -maxdepth 2 | sort
```

## Execution Order

1. `CLARITY_PREBUILD_FOUNDATION_MASTER_PLAN.md`
2. `CLARITY_USAGE_TRACKING_SIMPLIFIED_PLAN.md`
3. `PLAID_BACKEND_CORE_MASTER_PLAN.md`
4. `PLAID_MOBILE_AND_ACCOUNT_CONNECTION_MASTER_PLAN.md`
5. `CLARITY_DESIGN_SYSTEM_MASTER_PLAN.md`
6. `CLARITY_UNIFIED_PRODUCT_SHELL_MASTER_PLAN.md`
7. `CLARITY_FINANCIAL_EXPERIENCE_MASTER_PLAN.md`
8. `CLARITY_ASSISTANT_INTELLIGENCE_MASTER_PLAN.md`
9. `CLARITY_RELEASE_VALIDATION_MASTER_PLAN.md`

## Release Gate

This plan is complete only when all later subsystem plans have clear ownership, shared contracts, and no unresolved product identity ambiguity.

## Completion Ledger

- Phase 1 complete: current architecture and screen/data ownership are documented in `CLARITY_ARCHITECTURE_SNAPSHOT.md` and `docs/clarity/screen_data_map.md`.
- Phase 2 complete: one-app vocabulary is documented in `CLARITY_PRODUCT_VOCABULARY.md`.
- Phase 3 complete: Rex/product split cleanup rules and remaining allowed implementation names are documented in `CLARITY_REX_LABEL_CLEANUP_LEDGER.md`.
- Phase 4 complete: shared Clarity read models now define the truth source for screens and Assistant.
- Phase 5 complete: app-wide dark/minimal design token rules are defined before the UI rebuild.
- Phase 6 complete: multi-user data boundaries, service-role rules, and cross-user tests are documented.
- Phase 7 complete: execution gates and file-size exception rules are defined for later subsystem work.
- Phase 8 complete: prebuild readiness audit marks the next executable plan as `CLARITY_USAGE_TRACKING_SIMPLIFIED_PLAN.md`.

Final active-code banned-term scan completed on June 6, 2026. No active product code matches were found for legacy pending-memory or Rex-as-product terminology.
