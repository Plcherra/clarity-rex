# Test Refactor Plan — Execution Plan

**Purpose:** Split oversized test files on the **production assistant path** so launch fixes and Grok eval iterations are safer. Defer finance/Plaid splits until post-launch unless blocking CI.

**Estimated time:** 12–16 h for P0 (Phases 1–3); 8 h covers Phases 1–2 only  
**When:** Session 2 after Plan 01+03, or post-launch if tone work is higher priority  
**Orchestration:** Read `00-session-orchestration.md` — do **not** run parallel to Plan 03 in Session 1.

---

## Are 2k+ line tests dangerous before launch?

| Risk | Reality |
| --- | --- |
| **Runtime / users** | No — test size does not affect the app |
| **Launch debugging** | Yes — hard for humans and agents to find the right test |
| **Refactor during launch** | Yes — splitting + behavior changes in one PR causes regressions |
| **Keeping as-is with green CI** | Acceptable short-term if you **don't touch them** until post-launch |

**Recommendation:** Split **only P0 files** (assistant/voice/memory) before launch. Defer P2 (Plaid/finance) to after ship.

---

## Priority tiers

### P0 — Split before launch (production assistant path)

| Lines | File | Split strategy |
| ---: | --- | --- |
| 2419 | `services/rex-api/tests/test_chat_context_service.py` | By context section: recall, structured memory, open threads, financial guard, budgets |
| 2562 | `apps/mobile/test/voice_call_controller_test.dart` | `part` files or folder: lifecycle, save-card pause, streaming, reconnect, thinking indicator |
| 1115 | `services/rex-api/tests/test_chat_simple_memory_flow.py` | save flow / delete flow / voice parity / edge cases |
| 1050 | `services/rex-api/tests/test_memory_turn_service.py` | direct writes / corrections / deletes / summaries |
| 810 | `services/rex-api/tests/test_chat_service.py` | routing vs metadata vs assistant responses |
| 576 | `services/rex-api/tests/chat_service_fakes.py` | Extract fakes used by multiple files into `tests/fakes/` if reused |

### P1 — Split if touching area during launch

| Lines | File |
| ---: | --- |
| 933 | `test_memory_retrieval.py` |
| 774 | `test_voice_stream_routes.py` |
| 711 | `test_prompt_service.py` |
| 453 | `apps/mobile/test/voice_call_controller_test_fakes.dart` |
| 665 | `apps/mobile/test/memory_page_test_helpers.dart` |

### P2 — Post-launch (finance / Plaid)

| Lines | File |
| ---: | --- |
| 791 | `test_plaid_sync_service.py` |
| 633 | `test_plaid_transaction_sync.py` |
| 982 | `apps/mobile/test/financial_read_model_service_test.dart` |
| 799 | `apps/mobile/test/csv_import_service_test.dart` |
| 567 | `test_accountability_routes.py` |
| 741 | `test_accountability_service.py` |

---

## Split recipe (every file)

1. **One PR per source file** (or one logical half if file >2000 lines — two PRs max).
2. **Move tests, don't rewrite** — copy groups verbatim first; green CI; then optional dedup.
3. **Target ≤400 lines per file** (aligns with repo file-size policy).
4. **Naming:**
   - Backend: `test_chat_context_service_recall.py`, `test_chat_context_service_open_threads.py`, …
   - Mobile: `voice_call_controller_save_card_test.dart`, or `voice_call_controller/` folder with `main_test.dart` importing parts.
5. **Shared helpers:** extract to `*_test_helpers.py` / `*_test_support.dart` beside the group.
6. **Run full file's old test set** after split — count must match (pytest collect / flutter test list).

---

## Phased execution

### Phase 1 — `test_chat_context_service.py` (day 1)

1. Read file; list test function names and group by `describe` topic or fixture pattern.
2. Create 4–6 new files under `services/rex-api/tests/chat_context/`.
3. Move imports + shared fixtures to `chat_context/conftest.py` or `chat_context_fixtures.py`.
4. Delete original only when all tests moved.
5. Verify: `pytest tests/chat_context/ -q` and full `pytest tests/test_chat_context_service*` (should be empty/gone).

**Agent stop condition:** All tests pass; no file in group >400 lines.

### Phase 2 — `voice_call_controller_test.dart` (day 1–2)

1. Identify groups: init/connect, STT/TTS stream, save confirmation pause/resume, thinking indicator, reconnect.
2. Prefer Dart `part`/`part of` pattern already used in production voice controller.
3. Keep `voice_call_controller_test_fakes.dart` shared; do not duplicate fakes.
4. Verify: `flutter test test/voice_call_controller_test.dart` (or folder).

### Phase 3 — Memory flow tests (day 2)

**Step 0 (before split):** In `test_chat_simple_memory_flow.py`, apply Plan 01 hygiene — rename fixtures like "Be a goal/commitment" → "Be a goal". Then split.

Split in order:

1. `test_chat_simple_memory_flow.py` (step 0 + split, one PR)
2. `test_memory_turn_service.py`
3. `test_chat_service.py`

### Phase 4 — Prompt & voice routes (day 3, optional pre-launch)

1. `test_prompt_service.py`
2. `test_voice_stream_routes.py`
3. `test_memory_retrieval.py`

### Phase 5 — P2 backlog (post-launch)

Track in issue/PR; no pre-launch requirement.

---

## What NOT to do

- Do not merge test refactor with Grok prompt changes in one PR
- Do not rename test assertions "while you're in there"
- Do not delete tests to reduce line count
- Do not split `conftest.py` globally — only module-local fixtures

---

## Verify commands (after each PR)

```bash
cd services/rex-api && python -m pytest tests/ -q --tb=no | tail -3

cd apps/mobile && flutter test
```

---

## Agent handoff prompt (copy-paste)

```
Execute docs/archive/launch-prep/02-test-refactor-plan.md Phase N only.
One source file per PR. Move tests verbatim; no behavior changes.
Target ≤400 lines per output file. Run verify commands before done.
If eval prompt work is in flight (Plan 03), do not touch prompt/voice instruction production files.
```
