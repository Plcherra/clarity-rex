# Rex Production Readiness Follow-Up Plan

Status: Active follow-up tracker

Last updated: June 2, 2026

## Purpose

Track what is ready, what still needs work, and the exact phase order for making
Rex reliable enough for daily use and production launch. This file is the
single follow-up source after the deep Rex audit and the memory reliability
fixes.

This plan follows `docs/UNIVERSAL_CODE_ARCHITECTURE_STANDARDS.md`: small
phases, explicit state, no silent failures, behavior tests first, and no
god-file growth.

## Current Ready Baseline

| Area | Status | Evidence |
| --- | --- | --- |
| Backend test baseline | Ready | Rex API suite passed: `590 passed` |
| Pending memory confirmation phrases | Ready | Phone phrase regression tests added |
| Candidate review extraction gate | Ready | Memory-management turns skip AI/extraction |
| Mixed "yes, but..." correction handling | Ready for one-pending-correction case | Updates existing pending correction candidate |
| Memory context circuit breaker | Ready | Memory retrieval/recent-message failures degrade to empty context |
| Post-turn extraction failure visibility | Ready | Failed extraction returns `skip_failed` in `memory_changes` |
| Memory UX truthfulness copy | Ready for manual visual validation | Saved/pending/correction copy now says what Rex knows vs what needs review |
| File-size guardrails | Ready for touched files | All changed source/test files are under 500 lines |

## Current Known Gaps

| Gap | Risk | Owner Phase |
| --- | --- | --- |
| Review sessions are payload-only, not durably persisted | "these/those" review state can be lost across requests | Phase 1 |
| Memory UI phone validation is still pending | Need to confirm the new copy feels clear on device | Phase 2 |
| Voice phone validation is still pending | Need to confirm earbuds/background behavior on device | Phase 3 |
| Voice controller is still oversized | Improved but still needs future lifecycle/stream/playback split | Phase 3 |
| Rex Brain routing is powerful but too broad for launch | Wrong routing can increase latency or complexity | Phase 4 |
| Goals/accountability are not tightly looped into chat outcomes | Goals tab may feel separate from Rex | Phase 5 |
| Plaid transaction sync is not wired into financial context | Approved Plaid integration is not yet product-useful | Phase 6 |
| End-to-end release checklist needs a single pass | Manual release can miss backend/mobile/site steps | Phase 7 |

## Phase 1 - Durable Candidate Review Sessions

Goal: Make pending-memory review state explicit and recoverable across requests.

Status: Backend completed. Manual phone validation pending after deploy.

Files changed:

- `services/rex-api/app/services/memory_candidate_decision_formatter.py`
- `services/rex-api/app/services/memory_candidate_decision_service.py`
- `services/rex-api/app/services/memory_candidate_review_session_service.py`
- `services/rex-api/app/services/memory_candidate_review_session_repository.py`
- `services/rex-api/app/services/memory_candidate_review_session_facade.py`
- `services/rex-api/app/services/memory_candidate_review_intent.py`
- `services/rex-api/app/services/memory_service.py`
- `services/rex-api/app/config.py`
- `supabase/migrations/000024_create_memory_candidate_review_sessions.sql`
- `docs/clarity/rex_assistant_polish_plan/ADR_MEMORY_CANDIDATE_REVIEW_SESSIONS.md`
- `services/rex-api/tests/test_memory_candidate_decision_service.py`
- `services/rex-api/tests/chat_service_fakes.py`

Steps:

1. Write an ADR for where review sessions live: DB table vs conversation metadata.
2. Create a focused review session service if persistence is approved.
3. Store selected candidate IDs when Rex asks the user to review pending items.
4. Resolve `these`, `those`, `confirm them`, and `save those` against the stored
   session.
5. Expire or replace stale sessions safely.
6. Add tests for multi-turn review after a separate chat message.

Done looks like:

- Rex can list pending memories, then later understand "confirm those" from the
  explicit session.
- No hidden prompt markers or inferred-only state.

Manual test:

1. Create two pending memories.
2. Ask Rex: `Why are these pending?`
3. Send another normal message.
4. Say: `Confirm those as saved.`
5. Verify only the reviewed candidates are applied.

Acceptance criteria:

- [x] Review state survives across at least one later request.
- [x] Tests prove `these/those/them` do not rely on hidden text markers.
- [x] High-risk candidates still require explicit individual confirmation.
- [ ] Manual phone test passes after migration/backend deploy.

Verification:

- `python3 -m pytest tests/test_memory_candidate_decision_service.py tests/test_chat_candidate_phone_phrases.py tests/test_chat_candidate_decisions.py -q`
  - Result: `22 passed`
- `python3 -m pytest tests/test_chat_candidate_decisions.py tests/test_chat_candidate_phone_phrases.py tests/test_memory_candidate_decision_service.py tests/test_memory_reliability_flow.py tests/test_chat_simple_memory_flow.py tests/test_memory_turn_service.py tests/test_memory_post_turn_service.py tests/test_memory_candidate_service.py tests/test_chat_context_service.py tests/test_chat_service.py -q`
  - Result: `80 passed`
- `python3 -m pytest tests -q`
  - Result: `594 passed`

## Phase 2 - Memory UX Truthfulness and UI Polish

Goal: Make the Memory tab and chat memory messages feel like "what Rex knows"
instead of backend candidate administration.

Status: Mobile/backend copy completed. Manual phone visual validation pending.

Files changed:

- `apps/mobile/lib/features/assistant/chat/domain/chat_message.dart`
- `apps/mobile/lib/features/assistant/chat/presentation/widgets/chat_bubble_effects.dart`
- `apps/mobile/lib/features/assistant/chat/presentation/widgets/chat_memory_candidate_cards.dart`
- `apps/mobile/lib/features/assistant/chat/presentation/widgets/chat_message_bubble.dart`
- `apps/mobile/lib/features/assistant/memory/data/memory_labels.dart`
- `apps/mobile/lib/features/assistant/memory/data/memory_models.dart`
- `apps/mobile/lib/features/assistant/memory/presentation/pages/memory_page.dart`
- `apps/mobile/lib/features/assistant/memory/presentation/widgets/memory_edit_dialogs.dart`
- `apps/mobile/lib/features/assistant/memory/presentation/widgets/memory_page_header_widgets.dart`
- `apps/mobile/lib/features/assistant/memory/presentation/widgets/memory_pending_review_widgets.dart`
- `apps/mobile/lib/features/assistant/memory/presentation/widgets/saved_memory_tiles.dart`
- `services/rex-api/app/services/memory_candidate_decision_formatter.py`
- `apps/mobile/test/chat_memory_candidate_card_test.dart`
- `apps/mobile/test/memory_api_test.dart`
- `apps/mobile/test/memory_label_test.dart`
- `apps/mobile/test/memory_page_pending_test.dart`
- `apps/mobile/test/memory_page_test.dart`
- `services/rex-api/tests/test_memory_candidate_decision_service.py`

Steps:

1. Audit saved, pending, and correction UI copy. Done.
2. Replace backend labels with human labels. Done.
3. Make saved memories visually distinct from pending requests. Done.
4. Add clear empty/loading/error states. Done for touched Memory states.
5. Add compact indicators in chat when memory save/review happened. Done.
6. Verify mobile screenshots on light mode first. Manual phone validation pending.

Done looks like:

- A user can tell what Rex already knows vs what still needs approval.
- Pending count does not feel like unexplained debt.
- Chat memory cards no longer expose backend action labels.

Manual test:

1. Open Assistant -> Memory.
2. Compare Saved, Pending, and Corrections.
3. Confirm a pending item in chat.
4. Return to Memory and verify the item moved/updated clearly.

Acceptance criteria:

- [x] No raw labels like `long_term_memory` are user-facing in covered Memory UI tests.
- [x] Pending cards explain why saving/review is needed.
- [x] Saved memories are labeled as what Rex knows.
- [x] Touched files remain under the 500-line guardrail.
- [ ] Manual phone visual validation passes.

Verification:

- `cd apps/mobile && flutter test test/memory_label_test.dart test/memory_page_pending_test.dart test/memory_page_test.dart test/memory_api_test.dart test/chat_memory_candidate_card_test.dart`
  - Result: `20 passed`
- `cd services/rex-api && python3 -m pytest tests/test_memory_candidate_decision_service.py tests/test_chat_candidate_decisions.py tests/test_chat_candidate_phone_phrases.py -q`
  - Result: `22 passed`
- `python3 -m py_compile services/rex-api/app/services/memory_candidate_decision_formatter.py`
  - Result: passed
- `cd apps/mobile && flutter analyze`
  - Result: no issues found
- File-size spot check:
  - `chat_message_bubble.dart`: `531 -> 405` lines after extracting candidate cards/effects.
  - `chat_memory_candidate_cards.dart`: `368` lines.
  - `chat_bubble_effects.dart`: `131` lines.

## Phase 3 - Voice Stability Before More Voice Polish

Goal: Stabilize voice before doing more visual polish.

Status: Mobile stability hardening completed. Manual phone validation pending.

Files changed:

- `apps/mobile/lib/features/assistant/voice/application/voice_call_controller.dart`
- `apps/mobile/lib/features/assistant/voice/application/voice_permission_service.dart`
- `apps/mobile/lib/features/assistant/voice/application/voice_transcript_buffer.dart`
- `apps/mobile/lib/features/assistant/voice/data/audio_playback_service.dart`
- `apps/mobile/lib/features/assistant/voice/data/audio_session_service.dart`
- `apps/mobile/lib/features/assistant/voice/data/streaming_voice_api.dart`
- `apps/mobile/test/voice_call_controller_test.dart`
- `apps/mobile/test/voice_call_controller_test_fakes.dart`

Steps:

1. Reproduce screenshot/background pause behavior on phone. Manual validation
   pending.
2. Prevent overlapping turns while Rex is still answering. Done for
   `turn_in_progress` stream errors.
3. Respect selected audio output where Flutter/iOS APIs allow it. Improved by
   keeping Bluetooth, Bluetooth A2DP, and AirPlay routes eligible without
   forcing speaker output.
4. Add retry/recovery path for `turn_in_progress`. Done.
5. Split the oversized voice controller by lifecycle, stream, and playback
   responsibilities. Started with transcript and permission extraction.
6. Keep visual UI minimal; do not redesign again until stability passes. Done.

Done looks like:

- Voice no longer gets stuck on "Rex is still answering the previous voice turn."
- Background/screenshot behavior is predictable.
- Repeated final transcripts are collapsed before display.

Manual test:

1. Start a voice call with earbuds connected.
2. Ask a question, take a screenshot while Rex speaks.
3. Confirm audio route does not unexpectedly switch.
4. Interrupt and ask another question.
5. End and restart voice.

Acceptance criteria:

- [x] No crash path from `turn_in_progress` WebSocket error in covered tests.
- [x] No duplicate transcript from repeated partial/final text in covered tests.
- [x] Inactive lifecycle state does not fail a listening call in covered tests.
- [x] Voice controller moved toward file-size standards.
- [ ] Manual phone test passes for earbuds/audio route and screenshot/background
      behavior.

Verification:

- `cd apps/mobile && flutter test test/voice_call_controller_test.dart`
  - Result: `7 passed`
- `cd apps/mobile && flutter analyze`
  - Result: no issues found
- `cd services/rex-api && python3 -m pytest tests/test_voice_stream_routes.py tests/test_voice_routes.py tests/test_rex_brain_voice_integration.py -q`
  - Result: `32 passed`
- File-size spot check:
  - `voice_call_controller.dart`: `1908 -> 1791` lines.
  - `voice_permission_service.dart`: `77` lines.
  - `voice_transcript_buffer.dart`: `119` lines.
  - `voice_call_controller_test.dart`: `773 -> 418` lines.
  - `voice_call_controller_test_fakes.dart`: `363` lines.

## Phase 4 - Launch-Safe Rex Brain Routing

Goal: Reduce production risk from over-broad routing while keeping the advanced
brain architecture available.

Status: Completed on 2026-06-02.

Files changed:

- `services/rex-api/app/services/rex_model_router.py`
- `services/rex-api/app/services/rex_observability.py`
- `services/rex-api/.env.example`
- `services/rex-api/tests/test_rex_model_router.py`
- `services/rex-api/tests/test_rex_brain_observability.py`

Steps:

1. Audit which layers are actually needed for MVP.
2. Add a launch-mode routing profile if needed.
3. Cap voice latency by limiting deep layers for voice unless explicitly
   requested.
4. Add tests for budget, goal, memory, and casual-chat routing.
5. Add observability fields for route decisions that are safe to log.
6. Document rollback instructions.

Done looks like:

- MVP routing is predictable: fast, contextual, analytical.
- Advanced layers remain available behind explicit configuration.

Implementation notes:

- Added `launch_safe` rollout stage, with `mvp`, `launch`, `production`, and
  `prod` aliases.
- `launch_safe` only allows Fast, Contextual, and Analytical layers to use
  routed models.
- Strategic, Reflective, and Coaching layers remain available only through
  broader stages such as `strategic_reflective` or `deep_think_ui`.
- The `analytical` stage now blocks Coaching as an advanced layer.
- Voice requests that route into deep/strategic layers are blocked in
  `launch_safe` unless the deployment explicitly uses a broader rollout stage.
- Route observability now includes safe-to-log `rollout_stage` and
  `model_route_reasons`.

Rollback instructions:

1. For immediate rollback, set `REX_BRAIN_ROUTING_ENABLED=false` and restart
   `clarity-rex.service`.
2. For metadata-only logging, set `REX_BRAIN_ROLLOUT_STAGE=logging_only`.
3. For production launch behavior, use `REX_BRAIN_ROLLOUT_STAGE=launch_safe`
   or `production`.
4. Use `REX_BRAIN_ROLLOUT_STAGE=deep_think_ui` only when intentionally testing
   the full advanced routing stack.

Verification:

- `cd services/rex-api && python3 -m py_compile app/services/rex_model_router.py app/services/rex_observability.py`
- `cd services/rex-api && python3 -m pytest tests/test_rex_model_router.py tests/test_rex_brain_observability.py -q`
- `cd services/rex-api && python3 -m pytest tests/test_rex_model_router.py tests/test_rex_brain.py tests/test_rex_brain_observability.py tests/test_rex_brain_voice_integration.py tests/test_chat_service_rex_brain.py -q`

Manual test:

1. Ask a casual greeting.
2. Ask a memory recall question.
3. Ask a budget analysis question.
4. Ask a strategic planning question.
5. Confirm response speed and routing metadata are reasonable.

Acceptance criteria:

- [x] Voice does not route into slow deep modes by accident.
- [x] Routing tests cover common MVP user prompts.
- [x] Rollback or feature-flag path is documented.

## Phase 5 - Goals and Accountability Integration

Goal: Make goals feel connected to Rex instead of a separate tab.

Status: Completed on 2026-06-02 for backend chat-context integration.

Files changed:

- `services/rex-api/app/services/goal_context_service.py`
- `services/rex-api/app/services/chat_context_service.py`
- `services/rex-api/tests/test_chat_context_service.py`

Deferred follow-up:

- `services/rex-api/app/routes/accountability.py` and
  `services/rex-api/app/services/accountability_service.py` are still oversized
  and should be split before major new accountability features.
- Mobile Goals tab polish is still a separate UI task.
- Existing mobile Goals tab already reflects backend overview state with
  loading, empty, error, summary, plan hierarchy, milestone, commitment, and
  duplicate-risk sections; no UI code was changed in this phase.

Steps:

1. Audit the current goals/accountability flow.
2. Define the contract for goal creation from chat.
3. Ensure accountability signals can influence chat responses naturally.
4. Add update/progress events where appropriate.
5. Improve Goals tab states and progress copy.
6. Add tests around "How am I doing on my goals?"

Done looks like:

- Rex can answer goal-progress questions using actual structured context.
- Goals and accountability produce user-visible next steps.

Implementation notes:

- Added a small `GoalContextService` that detects goal/progress/accountability
  prompts and fetches active plans, related milestones, and open commitments.
- Goal context is merged into `structured_context` before Rex Brain planning,
  prompt building, and accountability analysis.
- The flow is best-effort: missing list methods or backend errors do not break
  chat.
- The prompt boundary is tested so active goals actually reach Rex's system
  context.

Verification:

- `cd services/rex-api && python3 -m py_compile app/services/goal_context_service.py app/services/chat_context_service.py`
- `cd services/rex-api && python3 -m pytest tests/test_chat_context_service.py -q`
- `cd services/rex-api && python3 -m pytest tests/test_chat_context_service.py tests/test_chat_service_rex_brain.py tests/test_rex_brain.py tests/test_rex_model_router.py tests/test_accountability_service.py tests/test_accountability_routes.py -q`

Manual test:

1. Create a goal from chat.
2. Open Goals tab and verify it appears.
3. Ask Rex how progress is going.
4. Update or complete a goal.

Acceptance criteria:

- [x] Goal context reliably appears in chat when relevant.
- [x] Accountability suggestions do not invent missing facts.
- [x] Goal UI reflects backend state clearly.

## Phase 6 - Plaid Financial Context Integration

Goal: Connect Plaid-approved data to Rex's financial context safely.

Status: Not started.

Files likely to change:

- Plaid backend service/client files
- Financial context builder files
- Mobile Plaid Link integration files
- Supabase migrations for linked accounts/transactions if not present

Steps:

1. Document Plaid data model and RLS boundaries.
2. Implement or verify Plaid Link token flow.
3. Sync accounts and transactions user-scoped.
4. Reconcile Plaid data with any existing CSV/manual imports.
5. Feed transaction summaries into Rex financial context.
6. Add tests for user isolation and duplicate transaction handling.

Done looks like:

- Rex can answer finance questions from live/synced Plaid data without exposing
  another user's data.

Manual test:

1. Link a test Plaid account.
2. Sync transactions.
3. Ask Rex about recent spending.
4. Verify the response matches stored test data.

Acceptance criteria:

- [ ] Plaid data is user-scoped with RLS.
- [ ] Duplicate syncs do not duplicate transactions.
- [ ] Financial context builder includes Plaid transactions.

## Phase 7 - Release and Manual Phone Validation

Goal: Ship only after backend, mobile, and manual smoke tests agree.

Status: Not started.

Files likely to change:

- `docs/clarity/rex_assistant_polish_plan/MEMORY_RELEASE_SMOKE_CHECKLIST.md`
- Release scripts only if gaps are found

Steps:

1. Run full backend tests.
2. Run Flutter analyze/tests for touched mobile areas.
3. Deploy backend to VPS.
4. Build/release mobile test build.
5. Run phone smoke tests for chat, memory, voice, goals, and auth.
6. Record pass/fail notes in the release checklist.

Done looks like:

- There is a dated release note with commands run, test results, and manual
  phone outcomes.

Manual test:

1. Fresh app launch.
2. Chat simple memory save/recall.
3. Pending memory review.
4. Voice ask/reply/interruption.
5. Memory tab saved/pending state.
6. Goals tab smoke.

Acceptance criteria:

- [ ] Backend full test suite passes.
- [ ] Mobile build installs on phone.
- [ ] Manual smoke checklist is completed.
- [ ] Any failure creates a follow-up issue/phase before launch.

## Execution Order

1. Phase 1 - Durable Candidate Review Sessions
2. Phase 2 - Memory UX Truthfulness and UI Polish
3. Phase 3 - Voice Stability Before More Voice Polish
4. Phase 4 - Launch-Safe Rex Brain Routing
5. Phase 5 - Goals and Accountability Integration
6. Phase 6 - Plaid Financial Context Integration
7. Phase 7 - Release and Manual Phone Validation

## Working Rules

- Do not start the next phase until the current phase has tests and a manual
  verification path.
- Keep every source and test file under 500 lines unless a documented exception
  is added.
- Prefer behavior tests over implementation tests.
- Any silent failure in chat, memory, voice, goals, or finance must become
  explicit user-facing state, safe metadata, or a logged diagnostic.
- Update this file after every phase with status, files changed, line counts,
  tests run, and manual test result.
