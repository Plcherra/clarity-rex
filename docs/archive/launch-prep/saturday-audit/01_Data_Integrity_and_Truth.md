# 01 — Data Integrity and Truth

**Covers:** Truth-rule violations, confirm-card honesty, durable-write apply integrity, duplicate handling, finance audit trail gaps, and client-forgeable audit rows. Do this before observability and feature polish — a wrong “saved” claim is worse than a crash.

**Primary paths:** `chat_controller_actions.dart`, `durable_write_applier.py`, `durable_write_service.py`, `memory_discipline_service.py`, `clarity_control_service.py`, `financial_audit_service.dart`, `action_truth_policy.py`

---

## Phase 1 — Stop fake success on confirm cards

### Issue: Confirm card can fake-apply on sync miss (C2)

- **Severity:** Critical
- **Why it matters:** UI can show “applied” when nothing was saved — direct truth-rule violation.
- **Estimated effort:** Small
- **Brief fix suggestion:** In `_syncClarityActionFromMessages`, never default to `applied`. Only mark applied when `memoryChanges` / `write_proposals` report `applied`; otherwise set `failed` with a clear message.

### Issue: Stream ends without done clears error (A1)

- **Severity:** High
- **Why it matters:** Partial SSE/stream failure can look like a quiet success and leave confirm state ambiguous.
- **Estimated effort:** Small
- **Brief fix suggestion:** In `chat_controller_send.dart`, if the stream ends without `ChatStreamDone`, set a user-visible error and do not `clearError`.

---

## Phase 2 — Honest apply failures on the backend

### Issue: DurableWriteApplier swallows apply exceptions (A2)

- **Severity:** High
- **Why it matters:** Generic `applied: False` without logged detail hides data-loss root causes from ops.
- **Estimated effort:** Small
- **Brief fix suggestion:** Log exception class + safe message in `durable_write_applier.py`; return structured failure reason in `failed_memory_changes` (no secrets).

### Issue: Backend short-circuit “saved” copy before Knows visibility (A3)

- **Severity:** Medium
- **Why it matters:** Deterministic English success strings can overclaim if metadata/UI lag; truth policy helps but UX must stay honest.
- **Estimated effort:** Medium
- **Brief fix suggestion:** Keep short-circuit copy tied to confirmed apply results only; prefer “Tap confirm to save” / failure copy until `applied` is true.

---

## Phase 3 — Duplicate integrity at apply time

### Issue: Apply-time duplicate check can be skipped (M1)

- **Severity:** Medium
- **Why it matters:** State can change between propose and confirm; duplicates can land in Knows.
- **Estimated effort:** Medium
- **Brief fix suggestion:** Re-run `MemoryDisciplineService` (or equivalent duplicate check) inside `DurableWriteApplier._apply_memory` before write.

### Issue: Discipline `_safe_list` silently returns empty (A4)

- **Severity:** Medium
- **Why it matters:** Duplicate detection can silently degrade and allow duplicate creates.
- **Estimated effort:** Small
- **Brief fix suggestion:** On list failure, fail closed or emit a metric/alert; do not treat empty as “no related records” without signal.

### Issue: Simple memory propose path skips discipline (A5)

- **Severity:** Medium
- **Why it matters:** `propose_simple_memory` can bypass the same duplicate gates as the main turn path.
- **Estimated effort:** Medium
- **Brief fix suggestion:** Route simple proposes through the same discipline decision as structured/flat save intents.

---

## Phase 4 — Finance write audit parity

### Issue: Assistant finance writes skip audit events (H6)

- **Severity:** High
- **Why it matters:** Rex can change budgets/categories with no trail in the audit UI — hard to debug trust reports.
- **Estimated effort:** Medium
- **Brief fix suggestion:** On applied clarity finance actions, insert `financial_audit_events` with `source: 'assistant'` (same validation as native writes).

### Issue: Clients can forge financial_audit_events (M5)

- **Severity:** Medium
- **Why it matters:** Users can pollute their own audit trail; compliance value collapses.
- **Estimated effort:** Medium
- **Brief fix suggestion:** Restrict INSERT to service role / Edge Function, or validate event types server-side.

---

## Phase 5 — Goals / Open Threads integrity

### Issue: Mobile has no client-side max-5 Open Threads guard (A6)

- **Severity:** Medium
- **Why it matters:** Users only learn the cap after a 409; feels broken rather than guided.
- **Estimated effort:** Small
- **Brief fix suggestion:** Pre-check active thread count in `accountability_controller` before create; show friendly localized message.

### Issue: Accountability errors surface raw `toString()` (A7)

- **Severity:** Medium
- **Why it matters:** Raw exceptions break honesty and Spanish UX; users see stack-ish English.
- **Estimated effort:** Small
- **Brief fix suggestion:** Map through `friendlyServiceError` / l10n like chat errors.

---

## Phase 6 — Pending proposal hydration honesty

### Issue: Pending write hydration silently swallowed on reopen (A8)

- **Severity:** Medium
- **Why it matters:** Reopening a conversation can hide a still-pending confirm, leaving the user unsure what was saved.
- **Estimated effort:** Small
- **Brief fix suggestion:** On `getPendingWriteProposal` failure, surface a non-blocking banner; on success, always show the pending card.

---

## Phase 7 — Verification gate

### Issue: Memory / plan confirm manual truth pass (A9)

- **Severity:** High
- **Why it matters:** Automated tests cover backend flows; UI truth bugs only show on device.
- **Estimated effort:** Small (manual)
- **Brief fix suggestion:** Run: propose → confirm → item in Knows/Goals; propose → reject → nothing saved; kill network mid-confirm → card shows failed, not applied. Include voice confirm dialog path.
