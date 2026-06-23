# Clarity Beta Hardening Issues

This file turns the current audit and frontend contract assessment into five
small, reviewable work issues. The order is intentional: get the backend green,
protect financial truth, prove the app manually on device, then improve the
mobile session shell and clean up stale docs.

Source context:

- `cursor_frontend_contract_assessment.md`
- `CLARITY_LAUNCH_FINAL_PLAN.md`
- `Manual smoke list for this session.txt`
- `docs/PROJECT_MAP.md`

## Recommended Execution

Run one focused work item per issue unless the diff is tiny. The safest combined
agent pass is Issue 1 plus Issue 2, because both are backend trust hardening.
Do not combine the backend truth guard with the mobile session shell in one pass.

1. Backend Voice Test Green Plan
2. Finance Truth Guard Plan
3. Manual Beta Smoke Plan
4. Mobile Assistant Session Shell Plan
5. Docs Cleanup Plan

## Issue 1: Backend Voice Test Green Plan

**Goal**

Make the backend suite green again by fixing the voice TTS chunking test drift
around `turn_generation`.

**Why Now**

The backend is otherwise close, but red tests block safe beta work. The audit
identified failures in `services/rex-api/tests/test_voice_tts_chunking.py` where
direct unit tests no longer match the current `_stream_chat_and_audio` contract.

**Scope**

- Update `services/rex-api/tests/test_voice_tts_chunking.py` to pass the current
  voice turn generation argument.
- Touch `services/rex-api/app/services/voice_stream_response_writer.py` only if
  the production method signature or default behavior is genuinely wrong.
- Keep this as a test-contract fix unless investigation proves a runtime bug.

**Acceptance Criteria**

- `test_voice_tts_chunking.py` passes.
- Full backend pytest suite passes.
- Voice stream tests still verify early audio chunking, final response emission,
  and memory/recall truth handling.
- No production voice behavior is changed unless needed to match the tested
  contract.

**Verification**

```powershell
cd services/rex-api
$env:PYTHONPATH=(Get-Location).Path
pytest tests/test_voice_tts_chunking.py
pytest -q
```

## Issue 2: Finance Truth Guard Plan

**Goal**

Make Rex refuse financial answers when financial context is missing, unavailable,
degraded, or incomplete.

**Why Now**

Clarity's core trust promise is that Rex must not guess about money. The backend
currently strips financial context for non-finance turns, but finance turns can
still proceed when no usable financial context was attached.

**Scope**

- Add a deterministic finance guard in the production `ChatService` /
  `SimpleRexBrain` path.
- If intent is financial and context is absent or degraded, return a clear answer
  such as: "I do not have your financial data available for this turn, so I
  cannot answer that without guessing."
- Preserve the existing rule that financial context is not sent on non-financial
  turns.
- Add backend tests for chat and voice parity.
- Do not invent fallback balances, transactions, merchants, budgets, or account
  names.

**Key Files**

- `services/rex-api/app/services/chat_service.py`
- `services/rex-api/app/services/rex_intent_router.py`
- `services/rex-api/app/services/prompt_financial_context.py`
- `services/rex-api/tests/test_chat_service.py`
- `services/rex-api/tests/test_voice_memory_parity.py`

**Acceptance Criteria**

- A finance question without financial context does not call the LLM for a money
  answer.
- A finance question with degraded or unavailable financial context gets a
  deterministic refusal instead of a guessed answer.
- A non-finance question still omits financial context from the prompt.
- A valid finance question with usable context still works.
- Voice and chat follow the same finance truth behavior.

**Verification**

```powershell
cd services/rex-api
$env:PYTHONPATH=(Get-Location).Path
pytest tests/test_chat_service.py tests/test_voice_memory_parity.py tests/test_rex_intent_router.py
pytest -q
```

## Issue 3: Manual Beta Smoke Plan

**Goal**

Create and run a real-device beta smoke checklist for the trust-critical flows
that automated tests cannot fully prove.

**Why Now**

Mobile and backend tests are strong, but beta trust depends on real device
behavior: voice audio, tab switching, delete-to-Knows refresh, old chat recall,
and finance no-guessing.

**Scope**

- Convert `Manual smoke list for this session.txt` into a pass/fail runbook.
- Run on a physical device against the intended beta API environment.
- Record environment, app build, API URL, account used, and pass/fail notes.
- Fix only launch blockers found by this smoke pass.

**Checklist Areas**

- Voice from Chat: speak, hear reply, type during voice, end voice, continue
  normal typing.
- Voice latency and gaps: short question, longer finance-shaped question, resume
  listening after speech.
- Delete to Knows: save or seed a memory, ask Rex to delete it, confirm, verify
  Knows active-only no longer shows it.
- Recall truth labeling: ask about mom, money/gift, games, and first PC game
  from a new chat; verify chat history is not called saved memory.
- Finance no-guessing: ask a finance question with unavailable/degraded context
  and confirm Rex refuses to guess.
- Chats filters: date filters plus search.
- Upload errors: gallery, camera, readable PDF, scanned/no-text PDF, oversized
  PDF if easy.
- Regression: Dashboard, Accounts, Budgets, Assistant, Knows, Goals, and Chats
  still load.

**Acceptance Criteria**

- All P0 smoke flows pass on device.
- Any failure has a short repro, expected behavior, actual behavior, and owner.
- No beta launch proceeds with a known false success, money guess, voice dead-end,
  or delete-to-Knows drift.

**Verification**

Use the runbook produced from this issue and attach the completed notes to the
release checklist or active launch plan.

## Issue 4: Mobile Assistant Session Shell Plan

**Goal**

Improve beta UX around active assistant sessions without changing the Rex brain
or creating a second voice state.

**Why Now**

The frontend contract is structurally sound, but the mobile audit found three
beta UX blockers: active voice can continue with no visible controls outside
Chat, conversation list state can drift after new turns, and retry/error UX is
inconsistent across Assistant tabs.

**Scope**

- Add global voice mini-bar or shell-level chrome when `voiceCallProvider` is
  active.
- Keep voice state owned by the existing voice provider.
- Add End / Mute where supported / Return to Chat controls.
- Sync or invalidate conversation list state after turns that create or update a
  conversation.
- Add shared Rex retry/error copy for Chat, Chats, Knows, and Goals, reusing the
  memory error mapping pattern where practical.
- Add focused Flutter tests for the mini-bar, conversation sync, and retry
  banners.

**Key Files**

- `apps/mobile/lib/features/shell/presentation/home_shell.dart`
- `apps/mobile/lib/rex/presentation/assistant_screen.dart`
- `apps/mobile/lib/rex/chat/application/chat_controller.dart`
- `apps/mobile/lib/rex/chat/application/conversation_controller.dart`
- `apps/mobile/lib/rex/chat/presentation/pages/conversation_list_page.dart`
- `apps/mobile/lib/rex/chat/presentation/widgets/chat_transcript.dart`
- `apps/mobile/lib/rex/voice/application/voice_call_controller*.dart`
- `apps/mobile/lib/rex/memory/presentation/widgets/memory_page_header_widgets.dart`
- `apps/mobile/lib/rex/accountability/presentation/pages/accountability_page_shared.dart`

**Non-Goals**

- No frontend redesign.
- No second voice controller.
- No default natural barge-in for beta.
- No chat auto-save to Knows.
- No broad Goals feature expansion.

**Acceptance Criteria**

- If voice is active and the user leaves Chat, visible controls remain available.
- User can return to Chat and end the voice session from the global shell.
- New conversations appear in Chats without manual refresh after a successful
  turn.
- User-facing recoverable errors include a clear retry path.
- Existing voice, chat, memory, and routing tests remain green.

**Verification**

```powershell
cd apps/mobile
flutter test test/app_routing_test.dart test/assistant_navigation_test.dart test/voice_call_controller_test.dart
flutter analyze
flutter test
```

## Issue 5: Docs Cleanup Plan

**Goal**

Align stale docs with confirmed shipped behavior after Issues 1-4 are verified.

**Why Now**

The docs audit found several files that still describe old risks or old paths.
Cleaning them up before behavior is confirmed could hide real gaps, so this
should come after backend, finance truth, and smoke results are known.

**Scope**

- Rewrite `docs/brain/REX_BRAIN_MEMORY_FIXES.md` as a verification/status doc if
  the delete, recall, and Person aggregation behavior is confirmed.
- Update `docs/project-structure.md` to use actual paths such as
  `apps/mobile/lib/...`.
- Fix or remove stale voice README links in `services/rex-api/README.md`.
- Align `.cursor/skills/simplicity-auditor/SKILL.md` references to current line
  counts only if updating local project skills is intentional.
- Keep archived docs archived; do not revive old Rex Brain v2 plans for beta.

**Acceptance Criteria**

- Active docs describe the production path: `ChatService` plus `SimpleRexBrain`.
- Docs clearly separate saved memory from chat history.
- Launch docs include a pass/fail checklist or link to the completed smoke
  runbook.
- No stale doc tells the team to fix behavior already verified by tests and
  manual smoke.

**Verification**

```powershell
rg "lib/" docs services/rex-api/README.md
rg "voice_pipeline_checklist|cloud_voice_contract|google_tts_setup" services/rex-api/README.md docs
rg "chat_context_service.py.*1400|Launch-complete|Current Issues Summary" docs .cursor/skills
```

## Work Split Guidance

Use these as separate issues or agent runs:

- First pass: Issue 1 only, or Issue 1 plus Issue 2 if time allows.
- Second pass: Issue 3 runbook and real-device execution.
- Third pass: Issue 4 mobile shell.
- Final pass: Issue 5 docs cleanup after behavior is proven.

Avoid doing all five in one run. That would mix test repair, backend truth
policy, manual QA, frontend UX, and documentation changes in one diff.
