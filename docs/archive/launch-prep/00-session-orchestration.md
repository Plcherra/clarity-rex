# Launch Prep — Session Orchestration

**Read this first.** The three plans below share files. This doc assigns ownership, prevents parallel edits, and defines what fits in ~8 hours vs multi-session.

| Plan | File |
| --- | --- |
| 01 Hygiene | `01-cleanup-hygiene-plan.md` |
| 02 Test refactor | `02-test-refactor-plan.md` |
| 03 Grok eval | `03-grok-eval-plan.md` |

---

## Can all three plans run in ~8 hours?

**Full scope of all three: no** — original estimates were 0.5–1 day + 2–4 days + 1–2 days.

**Your pace (~7 h for prior doc-driven fixes): yes for a high-value subset.**

| Scope | Fits ~8 h? | What you get |
| --- | --- | --- |
| **01 complete + 03 complete** | **Yes** | Dead refs gone, prompts/voice A/B shipped — **best launch ROI** |
| **01 + 02 Phase 1 only** | **Tight** | Hygiene + one 2400-line split; no Grok tone work |
| **01 + 02 P0 complete + 03 complete** | **No** (~20–28 h) | Full pre-launch ideal; split across 3 sessions |
| **02 P0 complete alone** | **No** (~12–16 h) | Safer tests; no user-visible tone change |

**Recommended 8-hour session (Session 1):** Plan **01** then Plan **03** (skip Plan 02 unless CI is blocked).

**Recommended 8-hour session (Session 2):** Plan **02** Phase 1 + Phase 2 only.

---

## File ownership matrix

**Rule:** Only one plan may *edit* a file per session. Read/verify is OK.

| File | Plan 01 | Plan 02 | Plan 03 | Resolution |
| --- | --- | --- | --- | --- |
| `test_chat_simple_memory_flow.py` | rename strings | **full split** | — | **01 skips this file**; hygiene strings done in **02 Phase 3 step 0** before split |
| `test_prompt_service.py` | read-only (assertion) | Phase 4 split | Phase 3 extend | **03 uses new file** `test_personality_prompt_regression.py` until split done |
| `test_save_intent_guards.py` | verify only | — | optional extend | **03 adds tests here** only if eval finds gap; else read-only |
| `voice_call_controller_test.dart` | verify only | **Phase 2 split** | — | No conflict if 01 only runs tests |
| `prompt_constants.py` | — | — | **edit** | 03 only |
| `voice_stream_config.py` | — | — | **edit** | 03 only |
| `prompt_service.py` | — | — | read (assembly) | 03 only for production edits |
| `save_intent_guards.py` | — | — | optional | Separate micro-PR if eval finds save gap |
| `test_chat_context_service.py` | — | **Phase 1 split** | — | 02 only |
| `test_memory_turn_service.py` | — | Phase 3 split | — | 02 only |
| `test_chat_service.py` | — | Phase 3 split | — | 02 only |
| `chat_service_fakes.py` | — | extract if needed | — | 02 only |
| `docs/PROJECT_STRUCTURE.md` | **edit** | — | — | 01 only |
| `test_brain_trust_e2e.py` | commitment strings | — | — | 01 only |
| `test_rex_intent_router.py` | commitment strings | — | — | 01 only |
| `test_p3_trust_regressions.py` | commitment strings | — | — | 01 only |
| `test_project_name_cleanup.py` | remove commitments fake | — | — | 01 only |
| `test_conversation_pending_action.py` | fixture strings | — | — | 01 only |
| `test_memory_discipline_rollout.py` | commitments field | — | — | 01 only |

---

## Merged work (avoid duplicate agents)

### Merge A — `test_chat_simple_memory_flow.py`

- **Removed from Plan 01 Phase 1** (was duplicate).
- **Added to Plan 02 Phase 3 step 0:** rename "goal/commitment" fixtures, then split.

### Merge B — Prompt regression tests

- **Plan 03 Phase 3** creates `tests/test_personality_prompt_regression.py` (small, ~50 lines).
- After Plan 02 Phase 4 splits `test_prompt_service.py`, optionally move assertions into the split group — post-launch cleanup.

### Merge C — Verify commands

- Plan 01 Phase 4 = hygiene verify subset.
- Plan 03 Phase 3 = add `test_personality_prompt_regression.py` + run `test_save_intent_guards.py`.
- Plan 02 = full pytest after each split PR.
- **Do not run full `flutter test` in every plan** — only touched areas.

---

## Session schedule (recommended)

### Session 1 (~8 h) — ship behavior

| Block | Plan | Task | ~Time |
| --- | --- | --- | --- |
| 1 | 01 | Phases 0–3 (skip `test_chat_simple_memory_flow.py`) | 1.5 h |
| 2 | 01 | Phase 4 verify + Phase 5 PR | 0.5 h |
| 3 | 03 | Phases 0–1 checklist + baseline | 1.5 h |
| 4 | 03 | Phase 2 prompt + voice config | 2 h |
| 5 | 03 | Phase 3 new regression file + Phase 4 A/B | 2 h |
| 6 | 03 | Phase 5 ship | 0.5 h |

**Defer:** Plan 02 entirely to Session 2 unless blocked.

### Session 2 (~8 h) — ship test safety

| Block | Plan | Task | ~Time |
| --- | --- | --- | --- |
| 1 | 02 | Phase 1 `test_chat_context_service.py` | 3.5 h |
| 2 | 02 | Phase 2 `voice_call_controller_test.dart` | 3.5 h |
| 3 | — | PR + verify | 1 h |

**Defer:** Plan 02 Phases 3–4 to Session 3 or post-launch.

### Session 3 (~8 h, optional pre-launch)

| Block | Plan | Task |
| --- | --- | --- |
| 1 | 02 | Phase 3 memory splits (+ step 0 hygiene on `test_chat_simple_memory_flow.py`) |
| 2 | 02 | Phase 4 if prompt/voice route tests still painful |

---

## Agent handoff — Session 1 starter prompt

```
Read docs/archive/launch-prep/00-session-orchestration.md first.

Session 1 scope only:
1. Execute 01-cleanup-hygiene-plan.md Phases 0–5 EXCEPT skip test_chat_simple_memory_flow.py (see orchestration Merge A).
2. Execute 03-grok-eval-plan.md Phases 0–5.
3. Do NOT execute Plan 02 (test splits) in this session.
4. For Plan 03 Phase 3, create tests/test_personality_prompt_regression.py — do not edit test_prompt_service.py.

Run verify commands from each plan before marking done.
One or two PRs: hygiene PR, then eval PR.
```

---

## Agent handoff — Session 2 starter prompt

```
Read docs/archive/launch-prep/00-session-orchestration.md first.

Session 2 scope only:
Execute 02-test-refactor-plan.md Phase 1 and Phase 2 only.
Do not touch prompt_constants.py or voice_stream_config.py.
One PR per split file. Move tests verbatim.
```

---

## When to combine plans into one agent

| Combine? | When |
| --- | --- |
| **01 + 03 in one session** | Yes — default Session 1; no file edit conflicts |
| **02 Phase 3 step 0 + split** | Yes — same agent, same PR for `test_chat_simple_memory_flow.py` |
| **03 + 02 Phase 4 on prompt tests** | No — use `test_personality_prompt_regression.py` instead |
| **01 + 02 same session** | Only if 01 finishes with zero overlap files and time remains (~10 h total) |
