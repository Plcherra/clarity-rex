# File 05 - Deep Think & Brain Routing Integration

Goal: make Deep Think and Rex Brain routing feel understandable, safe, and consistent across Chat and Voice without exposing internal routing machinery to normal users.

Working rule: advanced routing stays gated. Every phase must preserve the normal chat and voice fallback path unless the acceptance criteria explicitly enable a controlled rollout stage.

## Phase 1 - Audit Deep Think Entry Points

Goal: document every place a user can trigger Deep Think or Rex Brain routing.

Files to modify / create:

- `apps/mobile/lib/rex/brain/rex_deep_think_state.dart`
- `apps/mobile/lib/rex/chat/presentation/widgets/chat_input_bar.dart`
- `apps/mobile/lib/rex/chat/data/chat_api.dart`
- `services/rex-api/app/services/rex_brain.py`
- `services/rex-api/app/services/rex_model_router.py`
- Optional: `docs/clarity/rex_assistant_polish_plan/05_deep_think_brain_routing_notes.md`

Acceptance criteria:

- Chat toggle, explicit prompt phrases, backend flags, and rollout stages are documented.
- Voice-specific Deep Think behavior is documented separately from Chat.
- Current disabled/logging-only behavior is confirmed.
- No production behavior changes unless limited to docs or read-only notes.

Risks & mitigations:

- Risk: enabling expensive or slow routing too early.
- Mitigation: audit first and keep rollout-stage defaults unchanged.

Effort: Small.

## Phase 2 - Define User-Facing Deep Think Contract

Goal: define what Deep Think means to users without promising hidden chain-of-thought or magic.

Files to modify / create:

- `apps/mobile/lib/rex/chat/presentation/widgets/chat_input_bar.dart`
- `apps/mobile/lib/rex/chat/presentation/pages/chat_page.dart`
- `services/rex-api/app/services/rex_brain_prompts.py`
- Tests for copy/contract where practical

Acceptance criteria:

- Deep Think copy explains better analysis, planning, and tradeoffs.
- UI does not expose model names, raw layers, or internal routing reasons.
- Rex does not claim to think longer if backend routing is disabled.
- Tests or snapshots cover selected/unselected copy.

Risks & mitigations:

- Risk: overpromising intelligence.
- Mitigation: describe user-visible behavior, not internals.

Effort: Small.

## Phase 3 - Align Chat Deep Think Toggle State

Goal: make the Deep Think toggle predictable in the chat composer.

Files to modify / create:

- `apps/mobile/lib/rex/brain/rex_deep_think_state.dart`
- `apps/mobile/lib/rex/chat/presentation/widgets/chat_input_bar.dart`
- `apps/mobile/lib/rex/chat/application/chat_controller.dart`
- `apps/mobile/test/chat_input_bar_test.dart`

Acceptance criteria:

- Toggle selected state is visually clear.
- Toggle state applies to the next outgoing message only or persists by a documented rule.
- Empty composer state still allows users to understand the toggle.
- Tests cover toggle state and payload sent to backend.

Risks & mitigations:

- Risk: users leave Deep Think on accidentally.
- Mitigation: prefer next-message-only unless product review chooses persistent mode.

Effort: Medium.

## Phase 4 - Add Safe Routing Metadata Boundaries

Goal: ensure backend routing metadata is useful for debugging but not leaked to normal UI.

Files to modify / create:

- `services/rex-api/app/services/rex_observability.py`
- `services/rex-api/app/services/chat_service.py`
- `services/rex-api/app/models/chat.py`
- Backend tests

Acceptance criteria:

- Normal chat responses do not include raw routing metadata.
- Debug mode, if enabled, exposes only safe summarized fields.
- Observability logs include route, layer, profile, rollout stage, and status without private content.
- Tests assert private financial/memory values are not logged or returned in route metadata.

Risks & mitigations:

- Risk: logging sensitive context.
- Mitigation: log ids, counts, enums, and timings only.

Effort: Medium.

## Phase 5 - Voice-Specific Routing Guard

Goal: keep Voice fast and stable even when Rex Brain has enough context to escalate.

Files to modify / create:

- `services/rex-api/app/services/rex_brain.py`
- `services/rex-api/app/services/rex_model_router.py`
- `services/rex-api/app/services/voice_stream_session.py`
- `services/rex-api/tests/test_rex_brain_voice_integration.py`
- `services/rex-api/tests/test_voice_stream_routes.py`

Acceptance criteria:

- Normal voice turns stay fast/contextual unless user intent clearly asks for depth.
- Voice has lower output token caps than Chat.
- Deep voice requests can still escalate intentionally.
- Tests cover full-context voice that does not escalate and explicit deep voice that does.

Risks & mitigations:

- Risk: making Rex sound less intelligent in Voice.
- Mitigation: optimize for short spoken usefulness; offer to continue in Chat for deeper analysis.

Effort: Medium.

## Phase 6 - Backend Fail-Open And Rollback Guarantees

Goal: guarantee Rex Brain problems do not break normal Chat or Voice.

Files to modify / create:

- `services/rex-api/app/services/chat_service.py`
- `services/rex-api/app/services/voice_stream_session.py`
- `services/rex-api/app/services/rex_model_router.py`
- Backend tests

Acceptance criteria:

- Rex Brain planning failure falls back to base prompt/model path.
- Voice stream returns a useful retryable error only when fallback cannot complete.
- VPS env can disable routing without code changes.
- Tests cover planning failure fallback for chat and voice streaming.

Risks & mitigations:

- Risk: fail-open hides real bugs.
- Mitigation: log safe error class and route status while protecting user experience.

Effort: Medium.

## Phase 7 - Deep Think UI Feedback

Goal: give users subtle confirmation when Deep Think is active without making the UI noisy.

Files to modify / create:

- `apps/mobile/lib/rex/chat/presentation/pages/chat_page.dart`
- `apps/mobile/lib/rex/chat/presentation/widgets/chat_message_bubble.dart`
- `apps/mobile/lib/rex/chat/presentation/widgets/chat_input_bar.dart`
- Widget tests

Acceptance criteria:

- Active Deep Think state is visible before send.
- Sent message can show a small analyzed/deep marker if useful.
- Rex response does not expose internal route names.
- Loading/thinking state feels slower-but-intentional when deep mode is used.

Risks & mitigations:

- Risk: adding badges that make chat feel technical.
- Mitigation: keep labels plain and optional, such as `Deep Think`.

Effort: Medium.

## Phase 8 - Rollout Stage Controls And Readiness

Goal: make backend rollout stages explicit for testing and release.

Files to modify / create:

- `deploy/templates/rex-api.env.example`
- `services/rex-api/.env.example`
- `services/rex-api/app/main.py`
- `docs/deployment.md`
- Backend readiness tests

Acceptance criteria:

- Readiness endpoint reports Rex Brain configured status, rollout stage, and enabled flags.
- Env examples include safe defaults.
- Deployment docs explain disabled, logging_only, fast_contextual, analytical, and deep_think_ui stages.
- Tests cover readiness metadata.

Risks & mitigations:

- Risk: accidentally shipping advanced routing.
- Mitigation: default stage remains disabled or logging-only unless manually changed.

Effort: Small.

## Phase 9 - Deep Think Release Gate

Goal: verify routing integration is safe before Voice and Chat polish continue.

Files to modify / create:

- `docs/clarity/rex_assistant_polish_plan/05_deep_think_brain_routing.md`
- `docs/clarity/device_release_checklist.md` if Deep Think checks need updating

Acceptance criteria:

- Backend Rex Brain, model router, chat service, and voice integration tests pass.
- `flutter analyze` passes if mobile UI changed.
- Chat manual test confirms normal and Deep Think messages both work.
- Voice manual test confirms normal voice remains fast with routing flags enabled.
- Rollback command/env is documented.

Risks & mitigations:

- Risk: accepting backend green tests without phone validation.
- Mitigation: do not close this gate until phone Chat and Voice smoke tests run.

Effort: Small.
