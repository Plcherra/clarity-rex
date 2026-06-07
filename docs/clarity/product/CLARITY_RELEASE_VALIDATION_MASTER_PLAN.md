#9 Clarity Release Validation

Status: Draft

Last updated: June 6, 2026

## Purpose

Run the final cross-system release gate after subsystem hardening has already happened inside each plan.

## Core Outcome

By the end of this plan:

- Migrations and RLS are verified.
- Backend and mobile tests pass.
- Plaid sandbox lifecycle works.
- CSV fallback works.
- Assistant voice and truth parity work.
- Manual device validation is complete.

## Non-Goals

- Do not use this plan to hide subsystem cleanup.
- Do not start manual release validation before automated gates pass.
- Do not ship with known privacy, RLS, Plaid, or Assistant truth blockers.
- Do not perform first-pass Plaid, Assistant, UI, usage, or financial debugging here; those fixes belong in their subsystem plans.

## Current State

| Area | Current State | Risk |
| --- | --- | --- |
| Validation | Release checks exist but can become catch-all. | Bugs pile up late. |
| Migrations | Legacy and new migrations need final verification. | Multi-user privacy risk. |
| Mobile | Device-specific issues can appear late. | Release build surprises. |
| Assistant | Voice/truth parity needs final proof. | Trust regressions. |

## Target State

| Area | Target State | Benefit |
| --- | --- | --- |
| Migrations | Clean remote/local migration state. | Reliable deployment. |
| RLS | Cross-user isolation verified. | Multi-user safety. |
| Automated tests | Backend and Flutter suites pass. | Baseline confidence. |
| Manual QA | Device release checklist complete. | Real-world confidence. |
| Subsystem QA | Each subsystem has already produced its own QA report. | Final plan stays light. |

## Phase 1 - Migration Verification

Goal: Confirm Supabase migrations are ordered, applied, and safe.

Files to change:

- `docs/clarity/release_checklists/FULL_PROJECT_RELEASE_GATE.md`

Steps:

1. Run migration status checks.
2. Verify old pending-memory tables are archived/dropped according to final migration policy.
3. Verify Plaid and usage tables exist.
4. Verify existing user data remains intact.

Done looks like:

- Database migration state is release-ready.

Acceptance criteria:

- [ ] `supabase db push` reports expected state.
- [ ] No unexpected legacy table is active.
- [ ] Migration notes are updated.

## Phase 2 - RLS Verification

Goal: Prove multi-user isolation before release.

Files to change:

- `docs/clarity/release_checklists/FULL_PROJECT_RELEASE_GATE.md`
- `services/rex-api/tests/test_*user_isolation*.py`

Steps:

1. Verify RLS for profiles, Plaid, accounts, transactions, budgets, Assistant data, and usage tracking.
2. Run two-user backend tests.
3. Confirm service-role-only paths are not exposed to mobile.
4. Document failures and fixes.

Done looks like:

- User data cannot cross accounts.

Acceptance criteria:

- [ ] Cross-user RLS tests pass.
- [ ] Mobile cannot write sensitive backend-only records directly.
- [ ] Service-role operations are route/service guarded.

## Phase 3 - Full Backend Test Pass

Goal: Run backend test suite after all subsystem work.

Files to change:

- `docs/clarity/release_checklists/FULL_PROJECT_RELEASE_GATE.md`

Steps:

1. Run full rex-api pytest suite.
2. Run focused Plaid, Assistant, usage, financial, and voice tests.
3. Record failures and fixes.
4. Verify no hidden second LLM call path exists for normal turns.

Done looks like:

- Backend is release-stable.

Acceptance criteria:

- [ ] Full pytest suite passes.
- [ ] Focused subsystem tests pass.
- [ ] Normal chat/voice still uses one LLM call.

## Phase 4 - Full Flutter Analyze/Test Pass

Goal: Verify mobile build health.

Files to change:

- `docs/clarity/release_checklists/FULL_PROJECT_RELEASE_GATE.md`

Steps:

1. Run Flutter analyze.
2. Run Flutter tests.
3. Run release build command.
4. Verify no known iOS build warnings regress into failures.

Done looks like:

- Mobile app is build-ready.

Acceptance criteria:

- [ ] `flutter analyze` passes.
- [ ] `flutter test` passes.
- [ ] Release run succeeds on device.

## Phase 5 - Plaid Sandbox Final Smoke

Goal: Verify the Plaid subsystem QA report is complete and run one final sandbox lifecycle smoke test.

Files to change:

- `docs/clarity/plaid/PLAID_RELEASE_QA_REPORT.md`

Steps:

1. Confirm backend and mobile Plaid subsystem QA reports are complete.
2. Connect one sandbox bank.
3. Verify accounts and transactions sync.
4. Verify disconnect still works.
5. Verify Assistant can see persisted financial summary.

Done looks like:

- Plaid is ready to be the default data path without reopening subsystem implementation.

Acceptance criteria:

- [ ] Connect/sync/resync/disconnect pass.
- [ ] No tokens appear in logs.
- [ ] Assistant sees persisted financial data.
- [ ] Any Plaid blocker is sent back to the Plaid subsystem plan, not patched ad hoc here.

## Phase 6 - CSV Fallback Final Smoke

Goal: Verify the CSV fallback still works after Plaid becomes primary.

Files to change:

- `docs/clarity/release_checklists/FULL_PROJECT_RELEASE_GATE.md`

Steps:

1. Confirm CSV fallback QA exists in the financial/Plaid plan.
2. Import one representative CSV.
3. Verify account/transaction display.
4. Verify source labels and duplicate warnings.
5. Verify Assistant can reference imported financial data.

Done looks like:

- CSV fallback works without becoming primary.

Acceptance criteria:

- [ ] CSV import succeeds.
- [ ] CSV data displays correctly.
- [ ] Assistant can see imported summary.
- [ ] CSV remains a fallback path, not the primary onboarding path.

## Phase 7 - Assistant Voice Final Smoke

Goal: Verify the Assistant subsystem QA report is complete and run one final voice/truth smoke test.

Files to change:

- `docs/clarity/product/CLARITY_ASSISTANT_E2E_QA_REPORT.md`

Steps:

1. Confirm Assistant truth and voice QA reports are complete.
2. Test voice greeting and casual turn.
3. Test direct memory save.
4. Test correction update.
5. Test financial recall.
6. Record final latency and audio routing.

Done looks like:

- Voice is release-ready as the primary interface.

Acceptance criteria:

- [ ] Voice uses same context as chat.
- [ ] Voice memory save/correction works.
- [ ] Voice latency and playback pass manual gate.
- [ ] Assistant does not deny data visible in Clarity.

## Phase 8 - Manual Device Release Checklist

Goal: Complete final human validation.

Files to change:

- `docs/clarity/device_release_checklist.md`
- `docs/clarity/release_checklists/FULL_PROJECT_RELEASE_GATE.md`

Steps:

1. Run through the full device checklist.
2. Verify dark/minimal UI on major screens.
3. Verify auth, Plaid, CSV, Dashboard, Accounts, Budgets, Assistant, Profile.
4. Record blockers and final decision.

Done looks like:

- Clarity is ready for release or has a clear blocker list.

Acceptance criteria:

- [ ] Manual checklist is complete.
- [ ] No P0/P1 blocker remains.
- [ ] Release decision is documented.

## Verification Commands

```bash
supabase db push
cd services/rex-api && pytest
cd apps/mobile && flutter analyze
cd apps/mobile && flutter test
./scripts/mobile_release_run.sh
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

Ship only when every automated gate passes and manual device validation confirms Plaid, CSV fallback, Assistant, voice, usage tracking, and the unified dark Clarity UI are working together.
