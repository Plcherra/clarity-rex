# Launch Hygiene Pass — Execution Plan

**Purpose:** Remove dead references and doc drift before launch. No behavior changes unless a test is clearly testing a deleted system.

**Estimated time:** 1.5–2 h (full plan); ~1 h if skipping Merge A file (see orchestration)  
**When:** First — before test splits or Grok eval  
**Branch naming:** `launch/hygiene-<topic>` or one branch `launch/hygiene` if small  
**Orchestration:** Read `00-session-orchestration.md` for file ownership and 8-hour session scope.

---

## Success criteria

- [ ] No Python/Dart imports or routes reference deleted systems (`memory_candidates`, `memory_confirmations`, `rex_brain*`, live `commitments` table)
- [ ] Canon docs match repo reality (`docs/PROJECT_STRUCTURE.md` only — do not add new canon files)
- [ ] Assistant-path test subset green (see Phase 4 command)
- [ ] No untracked junk (`apps/mobile/test_output.txt`, stale `pytest_summary.txt` unless CI uses it)

---

## Phase 0 — Inventory (30 min, read-only)

Run and save output for the handoff commit message / PR notes:

```bash
# Dead-system grep (expect zero app hits except doc/archive/migrations)
rg -n "memory_candidate|memory_confirmation|rex_brain|commitments" \
  --glob '!supabase/migrations/*' \
  --glob '!docs/archive/*' \
  services/rex-api apps/mobile

# Oversized tests (context for Plan 02 — do not split in this plan)
wc -l services/rex-api/tests/test_chat_context_service.py \
      services/rex-api/tests/test_memory_turn_service.py \
      services/rex-api/tests/test_chat_simple_memory_flow.py \
      apps/mobile/test/voice_call_controller_test.dart
```

**Known already clean:** Application code has no `memory_candidates` / `memory_confirmations` table usage. DB archived via `20260604120456_archive_legacy_rex_memory_review_tables.sql`. `rex_brain*.py` already deleted.

---

## Phase 1 — Stale test & fake strings (1–2 h)

Replace or remove references to **removed product concepts**, not historical migration text.

| File | Action |
| --- | --- |
| `services/rex-api/tests/test_project_name_cleanup.py` | Remove `commitments` from `FakeProjectNameMemoryService` if table dropped |
| `services/rex-api/tests/test_p3_trust_regressions.py` | Change "What commitments do we have saved?" → goals/open-threads inventory phrasing |
| `services/rex-api/tests/test_rex_intent_router.py` | Same commitment → goal/thread wording |
| `services/rex-api/tests/test_brain_trust_e2e.py` | Same |
| `services/rex-api/tests/test_chat_simple_memory_flow.py` | **Skip here** — owned by Plan 02 Phase 3 step 0 (hygiene + split in one PR) |
| `services/rex-api/tests/test_conversation_pending_action.py` | Same |
| `services/rex-api/tests/test_memory_discipline_rollout.py` | Remove or update `commitments` count field if schema no longer has it |

**Do not change:** Tests that assert prompts **exclude** commitment language (e.g. `test_prompt_service.py` asserting `- commitment/` not in system prompt).

---

## Phase 2 — Doc drift (30 min)

| File | Action |
| --- | --- |
| `docs/PROJECT_STRUCTURE.md` | Remove or update line claiming `rex_brain*.py` exist as experiments (they are deleted) |
| `docs/PROJECT_STRUCTURE.md` | Clarify: candidates/confirmations are **DB-archived only**, production uses durable write + confirm cards |
| `docs/archive/NEXT_STEPS.md` | Mark rex_brain deletion items done if not already |

**Do not:** Edit old Supabase migrations or drop `legacy_*_archive` tables.

---

## Phase 3 — Junk & skipped tests (1 h)

| Item | Action |
| --- | --- |
| `apps/mobile/test_output.txt` | Delete if untracked debug output |
| `services/rex-api/pytest_summary.txt` | Delete or regenerate; note in PR if obsolete |
| Tests with `@pytest.mark.skip` / permanent skip for deleted features | Delete test or fix — no eternal skips for removed systems |
| `services/rex-api/tests/test_dumbbell_confirm_debug.py` | Review: debug-only? Remove if not asserting production behavior |

Audit skips:

```bash
rg -n "skip|xfail" services/rex-api/tests apps/mobile/test --glob '*.{py,dart}'
```

---

## Phase 4 — Verify assistant path (30 min)

```bash
cd services/rex-api
python -m pytest tests/ \
  test_brain_trust_e2e.py \
  test_chat_simple_memory_flow.py \
  test_save_intent_guards.py \
  test_action_truth_policy.py \
  test_voice_memory_parity.py \
  test_voice_stream_reliability.py \
  test_durable_write_proposal_flow.py \
  test_durable_delete_flow.py \
  -q

cd apps/mobile
flutter test test/voice_call_controller_test.dart \
             test/voice_transcript_thinking_indicator_test.dart \
             test/chat_controller_test.dart \
             test/voice_clarity_actions_test.dart
```

Fix **only failures introduced by hygiene edits** or obvious broken tests on the production path. Log unrelated failures for Plan 02 / post-launch.

---

## Phase 5 — PR checklist

- [ ] Single focused PR: "Launch hygiene: remove dead memory/commitment references"
- [ ] No production logic changes unless required by test fix
- [ ] Link to Plan 02 for oversized test splits (separate PRs)

---

## Agent handoff prompt (copy-paste)

```
Execute docs/archive/launch-prep/01-cleanup-hygiene-plan.md Phase N only.
Do not split large test files (that's Plan 02).
Run Phase 4 verify commands before marking done.
Follow PROJECT_STRUCTURE.md shipping rules; no new docs under docs/ root.
```
