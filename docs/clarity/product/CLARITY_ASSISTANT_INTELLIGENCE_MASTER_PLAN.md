#8 Clarity Assistant Intelligence

Status: Draft

Last updated: June 6, 2026

## Purpose

Make Assistant/Rex a trustworthy Clarity intelligence layer that uses the same facts, financial data, goals, and user information shown elsewhere in the app.

## Core Outcome

By the end of this plan:

- Assistant answers from shared Clarity read models.
- Voice and chat use the same brain/data path.
- Assistant does not deny data visible in Clarity.
- Memory corrections update existing records.
- Goals align with budgets and commitments.

## Non-Goals

- Do not restore pending memory cards.
- Do not add a second LLM extraction call.
- Do not let Assistant query Plaid directly.
- Do not keep legacy memory candidate or review-session paths as fallback behavior.

## Current State

| Area | Current State | Risk |
| --- | --- | --- |
| Assistant context | Can miss visible app data. | Trust breaks. |
| Voice path | Historically drifted from chat and memory paths. | Voice feels broken. |
| Corrections | Need consistent update/replace behavior. | Duplicate or stale information. |
| Goals/budgets | Not fully unified. | Guidance can feel disconnected. |

## Target State

| Area | Target State | Benefit |
| --- | --- | --- |
| Truth | Assistant uses shared read models. | Screen/chat agreement. |
| Voice | Same memory/goals/finance context as chat. | Primary interface works. |
| Memory | Direct save and correction update path. | Natural trust. |
| Goals | Goals connect to budgets and commitments. | Useful guidance. |

## Phase 1 - Voice Uses Same Brain Path As Chat

Goal: Ensure voice has the same context, memory save, goal, and correction behavior as chat.

Files to change:

- `services/rex-api/app/routes/voice.py`
- `services/rex-api/app/services/voice_*`
- `services/rex-api/app/services/chat_service.py`
- `services/rex-api/tests/test_voice_chat_context_parity.py`

Steps:

1. Route voice turns through the same simplified chat/brain service.
2. Preserve one LLM call per normal turn.
3. Ensure direct memory saves happen in voice.
4. Ensure corrections update in voice.
5. Ensure voice context includes the same shared read models as chat.

Done looks like:

- Voice is the primary interface and no longer a weaker path.

Acceptance criteria:

- [ ] Voice and chat use the same context builder.
- [ ] Voice direct memory save works.
- [ ] Voice correction update works.
- [ ] Normal voice turn uses one LLM call.
- [ ] Voice does not tell users to switch to chat to save or update Clarity information.

## Phase 2 - Memory Corrections Update Existing Records

Goal: Make corrections replace old information instead of creating duplicates, while removing any remaining legacy candidate/review code from active paths.

Files to change:

- `services/rex-api/app/services/memory_intent_service.py`
- `services/rex-api/app/services/memory_turn_service.py`
- `services/rex-api/tests/test_memory_corrections.py`
- Any active code still referencing MemoryCandidate, pending memory, review sessions, or legacy extraction/candidate flows

Steps:

1. Detect correction language.
2. Find matching existing memory/entity.
3. Update/override old record.
4. Avoid duplicate records for same fact.
5. Confirm naturally in the response.
6. Delete or fully disable remaining legacy pending/candidate/review memory paths from normal chat and voice.

Done looks like:

- "No, Somerville has one o and one m" updates the existing city fact.
- Normal turns cannot create pending memory candidates or review sessions.

Acceptance criteria:

- [ ] Correction updates existing memory.
- [ ] No duplicate city/birthday/name records are created.
- [ ] Voice and chat correction tests pass.
- [ ] `rg "MemoryCandidate|memory_candidate|pending memory|review session|memory_extraction" services/rex-api apps/mobile/lib` returns no active product path that can run on normal turns.

## Phase 3 - Assistant Truth Contract

Goal: Define exactly what Assistant must know when Clarity displays it.

Files to change:

- `docs/clarity/product/CLARITY_ASSISTANT_TRUTH_CONTRACT.md`
- `docs/clarity/product/CLARITY_SHARED_READ_MODELS.md`

Steps:

1. Define visible-data parity rule.
2. Define allowed uncertainty when data is stale or not loaded.
3. Define financial, user-info, goals, and budget context sources.
4. Define tests for "Assistant says it does not know" regressions.

Done looks like:

- Assistant truth is testable.

Acceptance criteria:

- [ ] Contract says visible Clarity data must be Assistant-visible.
- [ ] Contract defines stale/partial data language.
- [ ] Contract forbids separate memory guesses for financial truth.

## Phase 4 - Shared User Information Context Source

Goal: Make Assistant user facts come from the same "What Clarity Knows" records as the UI.

Files to change:

- `services/rex-api/app/services/memory_context_service.py`
- `services/rex-api/app/services/rex_brain_context.py`
- `services/rex-api/tests/test_assistant_user_info_truth.py`

Steps:

1. Load active user information records for context.
2. Include direct facts like name, city, birthday, preferences, important plans.
3. Keep memory context scoped and limited.
4. Add tests for name/city/mom birthday/movie plan recall.

Done looks like:

- Assistant can answer from saved user information.

Acceptance criteria:

- [ ] Assistant sees active user info shown in What Clarity Knows.
- [ ] No pending memory candidate system exists.
- [ ] Tests cover direct save and recall.

## Phase 5 - Shared Financial Context Source

Goal: Make Assistant financial context come from persisted Clarity financial read models.

Files to change:

- `services/rex-api/app/services/financial_context_service.py`
- `services/rex-api/app/services/rex_brain_context.py`
- `services/rex-api/tests/test_assistant_financial_truth.py`

Steps:

1. Build financial context from accounts, transactions, budgets, and dashboard summary.
2. Keep context small and lazy.
3. Include source/freshness status.
4. Add tests where Assistant sees the same account/budget data as UI.

Done looks like:

- Assistant does not claim ignorance of visible financial data.

Acceptance criteria:

- [ ] Financial context uses shared read model.
- [ ] Context remains small.
- [ ] Tests cover visible account/budget parity.

## Phase 6 - Goals Align With Budgets And Commitments

Goal: Make goals/accountability part of Clarity, not separate Assistant state.

Files to change:

- `services/rex-api/app/services/accountability_*`
- `services/rex-api/app/services/budget_*`
- `apps/mobile/lib/features/budgets/*`
- `apps/mobile/lib/features/assistant/*`

Steps:

1. Define goal/budget/commitment read model.
2. Ensure Assistant can reference budget state when discussing goals.
3. Ensure budget UI can surface relevant commitments.
4. Avoid duplicate goal and commitment concepts.

Done looks like:

- Goals and budgets reinforce each other.

Acceptance criteria:

- [ ] Assistant can answer goal/budget questions from shared data.
- [ ] Budget screen can show relevant commitments.
- [ ] No duplicate goal concepts leak to users.

## Phase 7 - Assistant Privacy And Trust Copy

Goal: Make Assistant data behavior feel clear and trustworthy.

Files to change:

- `apps/mobile/lib/features/assistant/*`
- `apps/mobile/lib/features/profile/*`
- `docs/clarity/product/CLARITY_ASSISTANT_TRUST_COPY.md`

Steps:

1. Replace backend-memory language with "What Clarity knows" user data language.
2. Explain editable information simply.
3. Avoid "review/pending/candidate" terminology.
4. Explain voice and chat use the same information.

Done looks like:

- Users understand what Assistant knows and can edit.

Acceptance criteria:

- [ ] No pending/review memory copy appears.
- [ ] Trust copy is short and user-centered.
- [ ] Profile and What Clarity Knows are consistent.

## Phase 8 - Voice Latency And Reliability QA

Goal: Verify voice is fast and stable enough to be primary.

Files to change:

- `docs/clarity/product/CLARITY_ASSISTANT_VOICE_QA_REPORT.md`
- `services/rex-api/tests/test_voice_*`

Steps:

1. Measure user-stop-to-response timing.
2. Measure STT, LLM, TTS, and playback latency via usage events.
3. Verify no phrase-cutoff regressions.
4. Verify speaker routing and playback continuity.

Done looks like:

- Voice has measurable latency and quality gates.

Acceptance criteria:

- [ ] QA report includes latency breakdown.
- [ ] Voice does not use hidden second LLM calls.
- [ ] Audio routing and playback continuity pass device check.

## Phase 9 - End-To-End Assistant Truth Tests

Goal: Prove Assistant, financial screens, user info, and voice agree.

Files to change:

- `services/rex-api/tests/test_assistant_truth_end_to_end.py`
- `docs/clarity/product/CLARITY_ASSISTANT_E2E_QA_REPORT.md`

Steps:

1. Test saved name/city recall.
2. Test corrected city update.
3. Test Plaid/account visibility once backend data exists.
4. Test budget/goal recall.
5. Test voice and chat parity.

Done looks like:

- Assistant is ready for final validation.

Acceptance criteria:

- [ ] Assistant does not deny visible Clarity data.
- [ ] Direct memory saving still works.
- [ ] Voice and chat parity tests pass.

## Verification Commands

```bash
cd services/rex-api && pytest tests/test_assistant_financial_truth.py tests/test_assistant_user_info_truth.py tests/test_voice_chat_context_parity.py tests/test_memory_corrections.py tests/test_assistant_truth_end_to_end.py
rg -n "memory candidate|pending memory|review session|I don't know your" services/rex-api apps/mobile/lib
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

This plan is complete only when Assistant/Rex can reliably speak from the same Clarity data the user sees.
