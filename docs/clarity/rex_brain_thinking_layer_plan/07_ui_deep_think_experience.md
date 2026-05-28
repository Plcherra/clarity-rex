# File 07 - UI Deep Think Experience

Goal: make Rex Brain visible enough to be trusted without making the assistant UI noisy or slower by default.

Status: `00.08` implementation complete for the first production-safe UI slice. Chat now has a compact per-message Deep Think toggle that sends an explicit `deep_think` request flag through mobile, backend routes, and `ChatService`. Debug metadata remains hidden in normal UI, and voice already exposes listening/thinking/speaking states through the inline voice panel.

## Phase 1 - Deep Think Toggle Design

Scope:

- Add a per-message composer control.
- Keep it off by default.
- Reset it after a successful send.
- Do not show model names, internal layer names, or debug metadata in normal UI.

Implemented:

- `ChatInputBar` now exposes a compact `Deep Think` / `Deep Think on` chip.
- `ChatPage` stores the toggle in a small Riverpod state provider.
- `ChatController` passes the explicit flag into the chat API.
- `ChatApi` serializes `deep_think` for JSON, multipart, streaming, and non-streaming requests.
- Backend `ChatRequest`, `/chat`, and `ChatService` accept the explicit flag.

Acceptance:

- Toggle is visible but compact in the composer.
- Toggle is disabled during active sends.
- Successful send clears the toggle.
- Existing chat/voice behavior stays feature-flagged by backend routing.

## Phase 2 - Explicit Deep Think Backend Contract

Scope:

- Preserve deterministic routing.
- Make explicit Deep Think stronger than phrase-only detection.
- Keep current production behavior safe when `REX_BRAIN_ROUTING_ENABLED=false`.

Implemented:

- Explicit `deep_think=true` reaches `RexBrainInput.user_requested_deep_thinking`.
- Router metadata records `user_requested_deep_thinking` as the escalation source.
- When routing is enabled, explicit Deep Think selects the reasoning model profile even for short messages.
- When routing is disabled, the flag is accepted but does not change the live model call.

Acceptance:

- Backend tests verify route parsing and model-profile escalation.
- Safe routing metadata still excludes raw user text and raw financial rows.

## Phase 3 - Auto-Routing Indicator

Future scope:

- Show subtle states like `Thinking`, `Checking context`, `Analyzing finances`, and `Reviewing memory` only after backend metadata is ready for client display.

Acceptance:

- User understands delays without seeing internal jargon.
- Indicators never expose private routing reasons in release UI.

## Phase 4 - Debug Brain Panel

Future scope:

- Developer-only panel for layer, model profile, routing reasons, prompt budget, and latency class.

Acceptance:

- Hidden in normal release unless debug mode is enabled.
- Debug panel never shows raw prompt text, secrets, or raw transaction rows.

## Phase 5 - Voice Thinking State

Current status:

- Inline voice panel already shows listening, thinking, speaking, muted, failed, retry, settings, interrupt, and end-call states.

Future scope:

- Add explicit voice Deep Think phrase handling to the UI only if user testing shows it is needed.

Acceptance:

- Voice remains low-latency by default.
- Deep voice reasoning requires explicit user intent or high-confidence complexity.

## Phase 6 - Deep Think Follow-Up Button

Future scope:

- After fast answers, optionally offer `Think deeper`, `Analyze`, or `Make a plan` actions.

Acceptance:

- User can escalate without retyping.
- Follow-up actions send explicit `deep_think=true`.

## Phase 7 - Conversation Continuity UI

Current status:

- Voice uses the chat conversation id and inline panel rather than a separate voice-only page.

Future scope:

- Surface voice turn transcripts as regular chat history where useful.

Acceptance:

- No separate confusing voice-only history.

## Phase 8 - Error UX And UI Tests

Implemented:

- Widget tests cover toggle display, selected label, and debug panel hidden by default.
- API tests cover `deep_think` serialization.
- Backend tests cover JSON/multipart route parsing and explicit deep-think escalation.

Future scope:

- Add full debug-panel tests after debug UI exists.
- Add follow-up button tests after follow-up UX exists.

Acceptance:

- Mobile and backend tests remain green.
