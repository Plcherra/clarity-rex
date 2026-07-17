# 04 — Aggressive deletion (break-OK)

**Status:** Complete (2026-07-17). Kill list deleted; reply-length UI/prompt stripped; plan 05 Phase A started on same branch.  
**Depends on:** [`03_canon_update.md`](03_canon_update.md) (merged)  
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
| CI | **May be red** (pytest/Flutter) until plan 05 — expected, not a reason to restore detectors |
| Body libs | Durable write, OpenThreadService, ClarityControl, Truth, settings still importable |
| Deploy | Do **not** leave prod users on a half-deleted brain; merge 04 only when 05 follows immediately (or keep prod on last green until 05 ships) |

### Platform notes

- **CI red = OK** during 04. Do not “fix” CI by re-adding eligibility/intent.
- **CD / staging** — not required for deletion.
- **VPS** — optional: pause prod deploy until 05 Phase I if cutover is atomic.

## 3. Phase A — Delete competing plan docs

- [x] Delete entire `docs/archive/` directory (all launch-prep / saturday-audit / etc.)
- [x] Search repo for other planning trackers that compete with `plans/01–05`; delete them (not move to archive)
- [x] Leave: `docs/MASTER_PLAN.md`, `docs/CLARITY_RULES.md`, `docs/PROJECT_STRUCTURE.md`, `plans/*`
- [x] Confirm `verify_docs_canon.sh` (post–plan 03) still passes

**Manual test:** `git status` shows archive removed; no new docs root files.

## 4. Phase B — Delete open-thread heuristic brain

- [x] Remove understanding/offer detection; keep storage service
- [x] Delete or gut eligibility/overlap/turn detector modules
- [x] Related detector tests deleted

**Keep:**

- `open_thread_service.py`, repository, routes, models, prompt **read** helpers only if they do not reintroduce offer logic (strip if needed)

**Manual test:** grep `topic_overlaps|HABIT_THREAD|find_overlapping|THREAD_OFFER` → no production hits (tests deleted with code).

## 5. Phase C — Delete memory / goal / plan short-circuit brains

- [x] Delete or gut memory/goal/plan short-circuit turn services
- [x] Matching detector tests deleted

**Keep:** REST/manual CRUD services, durable write propose/apply APIs for plan 05 to call.

**Manual test:** grep `MemoryTurnService|ConversationalPlanService|MemoryDeleteTurnService` → gone from orchestrator wiring.

## 6. Phase D — Delete intent router + short-circuit orchestrator

- [x] Delete or gut rex_intent_router and short-circuit orchestrator paths
- [x] Remove SimpleRexBrain.classify and deleted-service wiring from chat_service
- [x] Leave thin orchestrator shell (fail-loud brain redesign message; durable write confirm still works)

**Manual test:** starting API does not import deleted modules; one `/chat` call may 500 — acceptable.

## 7. Phase E — Strip always-on heavy context + reply length

- [x] Context load planner defaults all fetch flags to false (thin base turn)
- [x] Open thread prompt loader returns `{}` until plan 05
- [x] Strip `response_style_prompt` from prompt_service hot path
- [x] Do not replace with new detectors

**Manual test:** prompt assembly no longer pulls full finance by default; no `response_style_prompt` on the hot path (or dead code deleted).

## 8. Phase F — Test / CI cleanup

- [x] Delete or disable tests that only assert killed detectors
- [x] Leave or stub tests for durable write / open_thread_service / clarity actions / truth
- [x] CI may be red on assistant E2E — document in PR: “red until plan 05”

**Manual test:** `pytest` on kept body modules still meaningful; full suite red is OK if kill-list greps pass.

## 9. Phase G — Gate to plan 05

- [x] Kill-list greps clean in `app/` production imports
- [x] `docs/archive/` absent
- [x] No reintroduced overlap/intent/short-circuit understanding in orchestrator wiring
- [x] PR description states app assistant path intentionally broken *(branch pushed: `plan/04-aggressive-deletion` — open PR if `gh` unavailable: https://github.com/Plcherra/clarity-rex/pull/new/plan/04-aggressive-deletion)*
- [x] Start plan 05 immediately after merge (do not leave prod on broken brain without rebuild) *(Phase A started on this branch)*

## 10. Forbidden during plan 04

- “Just keep eligibility until embeddings land”
- Topic anchors / Smart Thread Overlap
- Soft-deprecating detectors behind flags
- Moving `docs/archive` to another folder name

## 11. Rollback policy

Rollback = git revert of the deletion PR. Do not rebuild detectors on rollback without an explicit product decision to abandon the simple-brain vision.
