# 01 — Data Integrity and Truth

**Status:** DONE (code + automated tests verified 2026-07-09). Safe to start plan 02.

**Covers:** Truth-rule violations, confirm-card honesty, durable-write apply integrity, duplicate handling, finance audit trail gaps, and client-forgeable audit rows. Do this before observability and feature polish — a wrong “saved” claim is worse than a crash.

**Primary paths:** `chat_controller_actions.dart`, `durable_write_applier.py`, `durable_write_service.py`, `memory_discipline_service.py`, `clarity_control_service.py`, `financial_audit_service.dart`, `action_truth_policy.py`

**Verification (2026-07-09):**
- Backend: 95 closest Plan-01 suite tests passed; 103 keyword-filtered (`durable_write|discipline|truth|pending_write|financial_audit|…`) passed.
- Flutter: 15 focused chat/memory/clarity tests passed.
- Remaining: Phase 7 **manual device** truth pass (propose/confirm/reject/network-fail) — recommended before marketing “saved” claims; not a code gap.

---

## Phase 1 — Stop fake success on confirm cards — DONE

### Issue: Confirm card can fake-apply on sync miss (C2) — DONE

- **Severity:** Critical
- **Why it matters:** UI can show “applied” when nothing was saved — direct truth-rule violation.
- **Estimated effort:** Small
- **Brief fix suggestion:** In `_syncClarityActionFromMessages`, never default to `applied`. Only mark applied when `memoryChanges` / `write_proposals` report `applied`; otherwise set `failed` with a clear message.
- **Done in:** `chat_controller_actions.dart` — only trusts terminal `applied`/`failed`/`dismissed`; otherwise sets `failed`.

### Issue: Stream ends without done clears error (A1) — DONE

- **Severity:** High
- **Why it matters:** Partial SSE/stream failure can look like a quiet success and leave confirm state ambiguous.
- **Estimated effort:** Small
- **Brief fix suggestion:** In `chat_controller_send.dart`, if the stream ends without `ChatStreamDone`, set a user-visible error and do not `clearError`.
- **Done in:** `chat_controller_send.dart` — stream-without-done sets error, returns null (no quiet success).

---

## Phase 2 — Honest apply failures on the backend — DONE

### Issue: DurableWriteApplier swallows apply exceptions (A2) — DONE

- **Severity:** High
- **Why it matters:** Generic `applied: False` without logged detail hides data-loss root causes from ops.
- **Estimated effort:** Small
- **Brief fix suggestion:** Log exception class + safe message in `durable_write_applier.py`; return structured failure reason in `failed_memory_changes` (no secrets).
- **Done in:** `durable_write_apply_failures.py` + applier `apply_failure_result(...)` with reason codes + capped logs.

### Issue: Backend short-circuit “saved” copy before Knows visibility (A3) — DONE

- **Severity:** Medium
- **Why it matters:** Deterministic English success strings can overclaim if metadata/UI lag; truth policy helps but UX must stay honest.
- **Estimated effort:** Medium
- **Brief fix suggestion:** Keep short-circuit copy tied to confirmed apply results only; prefer “Tap confirm to save” / failure copy until `applied` is true.
- **Done in:** Proposal copy uses “Tap confirm to save — nothing is saved until you confirm.” / text-mode “Say yes…”.

---

## Phase 3 — Duplicate integrity at apply time — DONE

### Issue: Apply-time duplicate check can be skipped (M1) — DONE

- **Severity:** Medium
- **Why it matters:** State can change between propose and confirm; duplicates can land in Knows.
- **Estimated effort:** Medium
- **Brief fix suggestion:** Re-run `MemoryDisciplineService` (or equivalent duplicate check) inside `DurableWriteApplier._apply_memory` before write.
- **Done in:** `_apply_memory` → `apply_disciplined_long_term_memory` (re-checks duplicate at apply).

### Issue: Discipline `_safe_list` silently returns empty (A4) — DONE

- **Severity:** Medium
- **Why it matters:** Duplicate detection can silently degrade and allow duplicate creates.
- **Estimated effort:** Small
- **Brief fix suggestion:** On list failure, fail closed or emit a metric/alert; do not treat empty as “no related records” without signal.
- **Done in:** `memory_discipline_list_loader.safe_discipline_list` — fail-closed `DisciplineContextLoadError` + log.

### Issue: Simple memory propose path skips discipline (A5) — DONE

- **Severity:** Medium
- **Why it matters:** `propose_simple_memory` can bypass the same duplicate gates as the main turn path.
- **Estimated effort:** Medium
- **Brief fix suggestion:** Route simple proposes through the same discipline decision as structured/flat save intents.
- **Done in:** `propose_simple_memory` → `find_long_term_memory_duplicate` before propose; clarification on discipline load failure.

---

## Phase 4 — Finance write audit parity — DONE

### Issue: Assistant finance writes skip audit events (H6) — DONE

- **Severity:** High
- **Why it matters:** Rex can change budgets/categories with no trail in the audit UI — hard to debug trust reports.
- **Estimated effort:** Medium
- **Brief fix suggestion:** On applied clarity finance actions, insert `financial_audit_events` with `source: 'assistant'` (same validation as native writes).
- **Done in:** `clarity_finance_audit.py` + `routes/clarity.py` `record_assistant_finance_audit`; `ASSISTANT_SOURCE = "assistant"`.

### Issue: Clients can forge financial_audit_events (M5) — DONE

- **Severity:** Medium
- **Why it matters:** Users can pollute their own audit trail; compliance value collapses.
- **Estimated effort:** Medium
- **Brief fix suggestion:** Restrict INSERT to service role / Edge Function, or validate event types server-side.
- **Done in:** migration `20260709000100_financial_audit_events_service_role_writes.sql` — authenticated SELECT only; no client INSERT.

---

## Phase 5 — Goals / Open Threads integrity — DONE

### Issue: Mobile has no client-side max-5 Open Threads guard (A6) — DONE

- **Severity:** Medium
- **Why it matters:** Users only learn the cap after a 409; feels broken rather than guided.
- **Estimated effort:** Small
- **Brief fix suggestion:** Pre-check active thread count in `accountability_controller` before create; show friendly localized message.
- **Done in:** `accountability_controller.createOpenThread` pre-check + `accountabilityOpenThreadMaxActive` l10n; covered by `accountability_controller_test.dart`.

### Issue: Accountability errors surface raw `toString()` (A7) — DONE

- **Severity:** Medium
- **Why it matters:** Raw exceptions break honesty and Spanish UX; users see stack-ish English.
- **Estimated effort:** Small
- **Brief fix suggestion:** Map through `friendlyServiceError` / l10n like chat errors.
- **Done in:** `accountability_controller` + `friendly_service_error.dart`.

---

## Phase 6 — Pending proposal hydration honesty — DONE

### Issue: Pending write hydration silently swallowed on reopen (A8) — DONE

- **Severity:** Medium
- **Why it matters:** Reopening a conversation can hide a still-pending confirm, leaving the user unsure what was saved.
- **Estimated effort:** Small
- **Brief fix suggestion:** On `getPendingWriteProposal` failure, surface a non-blocking banner; on success, always show the pending card.
- **Done in:** `chat_controller._hydratePendingWriteProposal` — success attaches cards; failure sets `chatPendingWriteHydrationFailed`.

---

## Phase 7 — Verification gate — PARTIAL (manual remaining)

### Issue: Memory / plan confirm manual truth pass (A9) — MANUAL REMAINING

- **Severity:** High
- **Why it matters:** Automated tests cover backend flows; UI truth bugs only show on device.
- **Estimated effort:** Small (manual)
- **Brief fix suggestion:** Run: propose → confirm → item in Knows/Goals; propose → reject → nothing saved; kill network mid-confirm → card shows failed, not applied. Include voice confirm dialog path.
- **Automated:** Backend + Flutter focused suites green (see header). **Still do on device before launch marketing.**
