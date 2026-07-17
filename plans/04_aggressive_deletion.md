# 04 — Aggressive deletion (break-OK)

**Status:** execution plan. Run only after plan 03 is merged.  
**Depends on:** [`03_canon_update.md`](03_canon_update.md)  
**Next:** [`05_simple_brain_implementation.md`](05_simple_brain_implementation.md)

## 1. Stance (non-negotiable)

- Delete **everything that does not align** with Grok-brain / body-execute.
- **Breaking the app is acceptable.** Prefer a red build and a clean rebuild (plan 05) over mismatching dual brains.
- **No compatibility shims** that reintroduce regex/overlap/intent understanding.
- **Delete old plans — do not archive.**

Kill list authority: [`02_alignment_and_kill_list.md`](02_alignment_and_kill_list.md) §5.

## 2. Success criteria for plan 04

| Gate | Pass condition |
|------|----------------|
| Docs | `docs/archive/` gone; `docs/` has only the three hearts |
| Grep | Kill-list understanding modules/symbols gone or unreachable |
| Shims | No new “temporary” detectors |
| Chat | **May fail** until plan 05 |
| Body libs | Durable write, OpenThreadService, ClarityControl, Truth, settings still importable |

## 3. Phase A — Delete competing plan docs

- [ ] Delete entire `docs/archive/` directory (all launch-prep / saturday-audit / etc.)
- [ ] Search repo for other planning trackers that compete with `plans/01–05`; delete them (not move to archive)
- [ ] Leave: `docs/MASTER_PLAN.md`, `docs/CLARITY_RULES.md`, `docs/PROJECT_STRUCTURE.md`, `plans/*`
- [ ] Confirm `verify_docs_canon.sh` (post–plan 03) still passes

**Manual test:** `git status` shows archive removed; no new docs root files.

## 4. Phase B — Delete open-thread heuristic brain

Remove understanding/offer detection; keep storage service.

**Delete or gut:**

- `services/rex-api/app/services/open_thread_eligibility.py`
- `services/rex-api/app/services/open_thread_overlap.py`
- `services/rex-api/app/services/open_thread_turn_update.py`
- Offer/consent/overlap branches in `open_thread_turn_service.py` (prefer delete file if nothing left but a husk)
- Related tests that only exist for those detectors

**Keep:**

- `open_thread_service.py`, repository, routes, models, prompt **read** helpers only if they do not reintroduce offer logic (strip if needed)

**Manual test:** grep `topic_overlaps|HABIT_THREAD|find_overlapping|THREAD_OFFER` → no production hits (tests deleted with code).

## 5. Phase C — Delete memory / goal / plan short-circuit brains

**Delete or gut:**

- `memory_turn_service.py`, `memory_turn_handle.py` (short-circuit path)
- `memory_intent_service.py` + `memory_intent_*.py` used for turn stealing
- `conversational_plan_service.py`, `conversational_plan_detection.py`
- Phrase short-circuit entry in `goal_command_service.py` (or delete if only a detector)
- `plan_target_date_update_service.py` detector path
- `memory_delete_turn_service.py` detector path
- Matching tests

**Keep:** REST/manual CRUD services, durable write propose/apply APIs for plan 05 to call.

**Manual test:** grep `MemoryTurnService|ConversationalPlanService|MemoryDeleteTurnService` → gone from orchestrator wiring.

## 6. Phase D — Delete intent router + short-circuit orchestrator

**Delete or gut:**

- `rex_intent_router.py`, `rex_intent_patterns.py`, `rex_intent_memory.py`, `rex_intent_finance.py` as turn authority
- `chat_turn_orchestrator_short_circuit.py`
- `SimpleRexBrain.classify` path that feeds short-circuits
- Wiring in `chat_turn_orchestrator.py` / `chat_service.py` that calls the above

**Leave a thin shell** that may error or no-op until plan 05:

- Still accept chat/voice HTTP
- Still construct orchestrator
- May return a clear “brain redesign in progress” or fail loudly — **no** silent heuristic fallback

**Manual test:** starting API does not import deleted modules; one `/chat` call may 500 — acceptable.

## 7. Phase E — Strip always-on heavy context

- [ ] Remove paths that auto-inject large LTM / full finance / full inventory every turn without a fetch action
- [ ] Leave hooks/comments pointing to plan 05 fetch capabilities
- [ ] Do not replace with new detectors

**Manual test:** prompt assembly code path no longer pulls full finance by default (grep call sites).

## 8. Phase F — Test / CI cleanup

- [ ] Delete or disable tests that only assert killed detectors
- [ ] Leave or stub tests for durable write / open_thread_service / clarity actions / truth
- [ ] CI may be red on assistant E2E — document in PR: “red until plan 05”

**Manual test:** `pytest` on kept body modules still meaningful; full suite red is OK if kill-list greps pass.

## 9. Phase G — Gate to plan 05

- [ ] Kill-list greps clean
- `docs/archive/` absent
- [ ] No reintroduced overlap/intent/short-circuit understanding
- [ ] PR description states app assistant path intentionally broken
- [ ] Start plan 05 immediately after merge (do not leave prod on broken brain without rebuild)

## 10. Forbidden during plan 04

- “Just keep eligibility until embeddings land”
- Topic anchors / Smart Thread Overlap
- Soft-deprecating detectors behind flags
- Moving `docs/archive` to another folder name

## 11. Rollback policy

Rollback = git revert of the deletion PR. Do not rebuild detectors on rollback without an explicit product decision to abandon the simple-brain vision.
