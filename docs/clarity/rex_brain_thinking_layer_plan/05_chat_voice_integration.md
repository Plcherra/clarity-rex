# File 05 - Chat Integration

Goal: integrate Rex Brain into normal and streaming chat behind `REX_BRAIN_ROUTING_ENABLED`, while keeping current production behavior unchanged when the flag is off.

Scope note: this file now covers master-plan phase `00.05` only. Voice-first integration moves to `00.06`, because voice has stricter latency, interruption, and audio-session rules.

## Phase 1 - ChatService Planning Hook

Build `RexBrainInput` inside `ChatService` after existing conversation, memory, accountability, file, and financial context are available.

Acceptance:

- `ChatService` constructs a chat-channel brain input for normal and streaming chat.
- The input includes safe feature flags only: file present, financial context present, structured memory present, goal/pending-commitment hints, conversation length, and explicit deep-think request.
- No raw user text, financial rows, secrets, prompt bodies, or memory bodies are logged through routing metadata.
- Routing disabled keeps chat output behavior unchanged.

Status: complete.

## Phase 2 - Non-Streaming Chat Prompt Contract

When routing is enabled, use `RexBrainDecision` to add the selected layer prompt contract to the existing Rex system prompt.

Acceptance:

- Routing disabled does not add Rex Brain prompt text.
- Routing enabled appends only a safe contract section to the system prompt.
- The contract includes layer prompt version, layer rules, and safe metadata.
- The contract section does not include raw financial records or secret fields.
- Existing non-streaming chat tests pass.

Status: complete.

## Phase 3 - Non-Streaming Model Profile Routing

When routing is enabled, pass the model and token limits from `RexModelRouter` into the AI call.

Acceptance:

- Fast chat routes to the fast model when configured.
- Analytical/strategic chat routes to reasoning when configured.
- Missing profile-specific models fall back to `GROK_MODEL`.
- Routing disabled sends no model override or Rex Brain token cap.
- Existing AI payload tests pass.

Status: complete.

## Phase 4 - Streaming Chat Prompt Contract

Use the same brain decision and prompt contract for SSE streaming chat.

Acceptance:

- Streaming chat emits the existing `conversation`, `token`, and `done` events.
- Streaming and non-streaming choose the same layer for the same input.
- Routing disabled keeps the streaming prompt unchanged.
- Existing streaming tests pass.

Status: complete.

## Phase 5 - Streaming Model Profile Routing

When routing is enabled, pass the same model route into `AIService.stream_response`.

Acceptance:

- Streaming fast chat can use the fast model.
- Streaming deep chat can use the reasoning model.
- Explicit `max_response_tokens` remains respected and can override the route output cap for caller-controlled streams.
- Existing streaming tests pass.

Status: complete.

## Phase 6 - Debug Metadata Boundary

Keep debug metadata safe and optional. Phase `00.05` prepares the safe route/context/model metadata but does not expose it to mobile UI by default.

Acceptance:

- `RexBrainDecision.metadata()`, context metadata, and model-route metadata remain serializable and private-content-safe.
- Chat responses do not expose debug metadata unless a future debug flag/response contract explicitly opts in.
- Tests assert private financial values are not copied into the Rex Brain contract section.

Status: complete for backend chat integration. UI/debug exposure is deferred to `00.08` and `00.09`.

## Phase 7 - Regression Tests

Add focused tests around chat integration.

Acceptance:

- Tests cover disabled routing preserving the AI call shape.
- Tests cover enabled non-streaming chat prompt/model routing.
- Tests cover enabled streaming chat prompt/model routing.
- Existing chat tests continue passing.

Status: complete.

## Phase 8 - Exit Criteria For 00.05

`00.05` is done when chat integration is real but safe:

- Chat routing exists behind `REX_BRAIN_ROUTING_ENABLED`.
- Disabled routing preserves the current production chat path.
- Non-streaming and streaming chat use the same decision path when enabled.
- Voice behavior is untouched and remains deferred to `00.06`.
- Backend tests for chat, router, prompts, context, model routing, AIService, and readiness pass.

Status: complete after verification.

# Master Phase 00.06 - Voice-First Integration

Goal: make voice use Rex Brain without making normal voice turns feel slower.

Scope note: this is the voice half that was intentionally deferred from `00.05`. It keeps voice on the same `ChatService`/memory/conversation path as chat, but passes `RexBrainChannel.VOICE` so the router can apply voice-specific latency and model-profile rules.

## Phase 1 - Voice Channel Contract

Pass `RexBrainChannel.VOICE` from upload voice turns and streaming voice turns into `ChatService`.

Acceptance:

- `/voice/turn` calls `ChatService.send_message(..., channel=RexBrainChannel.VOICE)`.
- `/voice/stream` calls `ChatService.stream_message(..., channel=RexBrainChannel.VOICE)`.
- Voice continues using the same conversation id and memory path as chat.

Status: complete.

## Phase 2 - Voice Fast Path

Let normal voice questions use the voice router contract instead of chat defaults.

Acceptance:

- Normal voice turns can use fast/standard profiles instead of forcing reasoning.
- Financial voice questions can stay standard/realtime unless explicit depth is requested or complexity is high.
- Voice response token caps stay short by default.

Status: complete.

## Phase 3 - Explicit Deep Voice Escalation

Support explicit deep-thinking phrases in voice without making every voice turn deep.

Acceptance:

- Phrases like `deep think`, `think deeply`, `analyze thoroughly`, and `reason through` can use the larger voice response cap.
- Explicit deep voice turns can route to reasoning when the router decides it is appropriate.
- Normal voice turns keep the short response cap.

Status: complete.

## Phase 4 - Upload Voice Integration

Apply the same voice-first contract to non-streaming upload voice turns.

Acceptance:

- `/voice/turn` receives the voice channel and short/deep token cap.
- TTS and voice metadata behavior stay unchanged.
- Existing voice route tests pass.

Status: complete.

## Phase 5 - Streaming Voice Integration

Apply the same voice-first contract to live streaming turns.

Acceptance:

- `/voice/stream` receives the voice channel and short/deep token cap.
- Existing websocket events remain unchanged: transcript, assistant token/audio, messages updated, assistant done.
- Interruption and empty-audio behavior remain unchanged.

Status: complete.

## Phase 6 - Voice Integration Tests

Add regression tests for voice-specific routing.

Acceptance:

- Tests prove normal financial voice questions route through voice channel without forcing reasoning.
- Tests prove explicit deep voice requests can use reasoning and a larger voice cap.
- Tests prove upload and streaming voice pass the voice channel into chat.
- Tests prove normal/deep voice token cap selection.

Status: complete.

## Phase 7 - Exit Criteria For 00.06

`00.06` is done when voice is wired into Rex Brain safely:

- Voice uses `RexBrainChannel.VOICE`.
- Normal voice turns remain low-latency and short.
- Explicit deep voice turns can opt into deeper routing.
- Chat behavior remains unchanged.
- Backend voice and Rex Brain tests pass.

Status: complete after verification.
