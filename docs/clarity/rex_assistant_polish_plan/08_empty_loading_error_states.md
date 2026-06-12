# File 08 - Empty, Loading, And Error UX

Goal: create a consistent Assistant-wide state system so empty, loading, degraded, offline, permission, and retry experiences feel calm and coherent.

Working rule: standardize state UX after the main surfaces are clearer. Avoid large redesigns; consolidate patterns that already proved useful in earlier files.

## Phase 1 - Audit Assistant State Surfaces

Goal: document all empty, loading, error, permission, degraded, and retry states across Assistant.

Files to modify / create:

- `apps/mobile/lib/rex/presentation/`
- `apps/mobile/lib/rex/chat/presentation/`
- `apps/mobile/lib/rex/voice/presentation/`
- `apps/mobile/lib/rex/memory/presentation/`
- `apps/mobile/lib/rex/accountability/presentation/`
- `apps/mobile/lib/rex/conversations/presentation/`
- Optional: `docs/clarity/rex_assistant_polish_plan/08_empty_loading_error_states_notes.md`

Acceptance criteria:

- Every Assistant state surface is listed with current copy and action.
- Duplicate patterns are identified.
- Missing retry or recovery actions are listed.
- No production behavior changes unless limited to docs or read-only notes.

Risks & mitigations:

- Risk: trying to redesign all states at once.
- Mitigation: audit first and consolidate only repeated primitives.

Effort: Small.

## Phase 2 - Define Assistant State Component Contract

Goal: define a small reusable component set for Assistant state surfaces.

Files to modify / create:

- `apps/mobile/lib/rex/presentation/widgets/assistant_state_view.dart`
- `apps/mobile/lib/rex/presentation/widgets/assistant_error_banner.dart`
- Widget tests

Acceptance criteria:

- State view supports icon, title, message, primary action, secondary action, and compact mode.
- Error banner supports retry and dismiss where appropriate.
- Components do not force cards inside cards.
- Tests cover empty, loading, error, and compact banner variants.

Risks & mitigations:

- Risk: generic component becomes too abstract.
- Mitigation: support only states needed by Assistant screens today.

Effort: Medium.

## Phase 3 - Standardize Empty States

Goal: make empty Assistant tabs useful and encouraging without sounding like marketing.

Files to modify / create:

- Assistant state components
- Chat, Memory, Goals, Chats empty states
- Widget tests

Acceptance criteria:

- Chat empty state offers practical starter prompts.
- Memory empty state explains saved memory and pending review.
- Goals empty state offers planning with Rex.
- Chats empty state offers starting a conversation.
- Copy is short and action-oriented.

Risks & mitigations:

- Risk: empty states become verbose instructions.
- Mitigation: keep one sentence plus one clear action.

Effort: Medium.

## Phase 4 - Standardize Loading States

Goal: reduce jumpy or inconsistent loading indicators across Assistant.

Files to modify / create:

- Assistant state components
- Memory, Goals, Chats, Chat, and Voice loading points
- Widget tests

Acceptance criteria:

- Initial loading has stable layout.
- Refresh loading is subtle and does not replace existing content unnecessarily.
- Voice thinking/listening states remain distinct from generic loading.
- Tests cover at least one full-page and one inline loading state.

Risks & mitigations:

- Risk: skeletons or spinners add visual noise.
- Mitigation: use minimal loading treatment unless content shape benefits from skeletons.

Effort: Medium.

## Phase 5 - Standardize Retryable Errors

Goal: make recoverable errors clear and consistent.

Files to modify / create:

- Assistant error components
- Chat, Voice, Memory, Goals, Chats error rendering
- Widget/controller tests

Acceptance criteria:

- Network/backend failures show retry.
- Retry action calls the correct controller method.
- Error copy does not expose stack traces or backend internals.
- Repeated errors do not create duplicate banners.

Risks & mitigations:

- Risk: hiding useful diagnostic detail.
- Mitigation: keep diagnostics in logs/debug metadata, not user copy.

Effort: Medium.

## Phase 6 - Standardize Permission And Configuration Errors

Goal: make microphone, speech, backend config, and service availability issues understandable.

Files to modify / create:

- Voice permission/error UI
- Assistant state components
- Backend readiness/error mapping if needed
- Tests for permission states

Acceptance criteria:

- Microphone/speech blocked states include Settings action when relevant.
- TTS/STT/backend unavailable states explain retry or contact-support path.
- App does not claim permission is blocked before requesting it.
- Tests cover denied and permanently denied microphone states.

Risks & mitigations:

- Risk: iOS permission states vary by device.
- Mitigation: combine tests with real-device permission reset/manual check.

Effort: Medium.

## Phase 7 - Partial And Degraded Data States

Goal: allow Assistant screens to show useful data even when one source fails.

Files to modify / create:

- Memory, Goals, Chats, and Chat controllers/views
- Backend response contracts only if needed
- Tests for partial data

Acceptance criteria:

- Goals can show loaded plans even if insights fail.
- Memory can show saved memories even if pending review fails.
- Chat can answer even if memory extraction fails.
- Partial-state copy is calm and does not imply data loss.

Risks & mitigations:

- Risk: masking backend failures.
- Mitigation: log failures and show subtle degraded indicators.

Effort: Medium.

## Phase 8 - State UX Release Gate

Goal: verify state consistency before final design-system and release readiness work.

Files to modify / create:

- `docs/clarity/rex_assistant_polish_plan/08_empty_loading_error_states.md`
- `docs/clarity/device_release_checklist.md`

Acceptance criteria:

- `flutter analyze` passes.
- State component tests pass.
- Relevant screen tests pass.
- Manual phone check covers empty Chat, empty Goals, loading Memory/Chats, voice permission blocked, backend retry, and partial data.
- Follow-up state improvements are moved to File 09 or File 10.

Risks & mitigations:

- Risk: approving states without testing real failure modes.
- Mitigation: simulate failures with fakes and perform at least one real backend-off/retry check when practical.

Effort: Small.
