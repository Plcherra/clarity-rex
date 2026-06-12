# File 06 - Voice Stability & UX

Goal: make Rex Voice stable, recoverable, and confidence-building on a real phone, including transcript visibility, latency, audio routing, and failure diagnostics.

Working rule: Voice is the highest-risk Assistant surface. Every phase must preserve a safe end-call path, avoid trapping users in listening/thinking states, and include real-device validation when platform behavior matters.

## Phase 1 - Audit Voice Call Lifecycle

Goal: document every voice state transition from permission request to listening, transcript, thinking, speaking, retry, interruption, and end call.

Files to modify / create:

- `apps/mobile/lib/rex/voice/application/voice_call_controller.dart`
- `apps/mobile/lib/rex/voice/domain/voice_call_state.dart`
- `apps/mobile/lib/rex/voice/presentation/`
- `services/rex-api/app/services/voice_stream_session.py`
- Optional: `docs/clarity/rex_assistant_polish_plan/06_voice_stability_ux_notes.md`

Acceptance criteria:

- Current state machine is documented.
- Known stuck states are listed.
- Backend error events are mapped to UI states.
- No production behavior changes unless limited to docs or read-only notes.

Risks & mitigations:

- Risk: changing voice behavior before understanding lifecycle.
- Mitigation: keep Phase 1 read-only and use it to define test cases.

Effort: Small.

## Phase 2 - Make Transcript Visibility Reliable

Goal: ensure users see what Rex heard while they speak and after the turn completes.

Files to modify / create:

- `apps/mobile/lib/rex/voice/application/voice_call_controller.dart`
- `apps/mobile/lib/rex/voice/presentation/`
- `apps/mobile/lib/rex/voice/data/streaming_voice_api.dart`
- Voice controller tests

Acceptance criteria:

- Partial transcript appears during listening when available.
- Final transcript replaces or confirms the partial transcript.
- Transcript clears only when a new turn starts or the user ends the call.
- Tests cover partial, final, and failed-turn transcript preservation.

Risks & mitigations:

- Risk: showing unstable partial text as final.
- Mitigation: visually distinguish partial from final when practical.

Effort: Medium.

## Phase 3 - Tune Listening Endpoint And Latency

Goal: reduce delay after the user stops talking while avoiding premature cutoffs.

Files to modify / create:

- `apps/mobile/lib/rex/voice/application/voice_call_controller.dart`
- `apps/mobile/lib/rex/voice/data/streaming_audio_capture_service.dart`
- `services/rex-api/app/services/voice_stream_session.py`
- `services/rex-api/app/config.py`
- Backend/mobile voice tests

Acceptance criteria:

- Endpoint timing is configurable and documented.
- Normal pauses do not instantly cut off the user.
- End-of-speech delay is measured in manual testing.
- Tests cover idle endpoint behavior and explicit utterance end behavior.

Risks & mitigations:

- Risk: latency improvements harm recognition accuracy.
- Mitigation: tune incrementally and record manual timing results.

Effort: Medium.

## Phase 4 - Improve Voice Error Recovery

Goal: make common failures recoverable without forcing the user to leave Assistant.

Files to modify / create:

- `apps/mobile/lib/rex/voice/application/voice_call_controller.dart`
- `apps/mobile/lib/rex/voice/presentation/`
- `services/rex-api/app/services/voice_stream_session.py`
- Voice tests

Acceptance criteria:

- Stream failure, no audio, permission denial, TTS failure, and backend timeout have distinct user copy.
- Retry restarts the correct part of the call.
- End call always works.
- Backend logs include safe diagnostic information for unexpected failures.

Risks & mitigations:

- Risk: exposing backend internals to users.
- Mitigation: keep detailed diagnostics in server logs and show simple recovery copy in UI.

Effort: Medium.

## Phase 5 - Audio Route And Earbud Confidence

Goal: make voice playback respect earbuds/Bluetooth where platform APIs allow, and make fallback behavior understandable.

Files to modify / create:

- `apps/mobile/lib/rex/voice/data/audio_session_service.dart`
- `apps/mobile/lib/rex/voice/data/audio_playback_service.dart`
- `apps/mobile/lib/rex/voice/application/voice_call_controller.dart`
- iOS native audio session files if present
- Manual test checklist

Acceptance criteria:

- Audio session configuration is documented for speaker, receiver, earbuds, and Bluetooth.
- Manual test covers music interruption and Rex playback route on earbuds.
- UI does not claim earbuds are active unless known.
- Fallback route behavior is documented.

Risks & mitigations:

- Risk: Flutter audio plugins expose limited route control.
- Mitigation: document platform limits and add native iOS handling only if necessary.

Effort: Medium.

## Phase 6 - Barge-In And Interruption Policy

Goal: define how Rex handles the user speaking while Rex is talking.

Files to modify / create:

- `apps/mobile/lib/rex/voice/application/voice_call_controller.dart`
- `apps/mobile/lib/rex/voice/data/streaming_audio_playback_queue.dart`
- `apps/mobile/lib/rex/voice/data/streaming_audio_capture_service.dart`
- Voice tests

Acceptance criteria:

- Barge-in is either intentionally disabled with clear behavior or enabled with tests.
- User can stop Rex while speaking.
- Interrupting does not leave playback or capture running in the background.
- Tests cover user interrupt during assistant speech.

Risks & mitigations:

- Risk: barge-in causes false positives and broken calls.
- Mitigation: keep disabled until confidence is high, but preserve manual stop controls.

Effort: Medium.

## Phase 7 - Voice UI Controls And State Copy

Goal: make Voice controls clear, calm, and consistent with Chat.

Files to modify / create:

- `apps/mobile/lib/rex/voice/presentation/`
- `apps/mobile/lib/rex/presentation/assistant_screen.dart`
- Voice widget tests

Acceptance criteria:

- Listening, thinking, speaking, retry, and issue states have distinct copy.
- Primary controls are microphone, end, and stop/retry depending on state.
- Controls do not collide with composer or bottom nav.
- Manual checks cover iPhone SE, iPhone 13/14 class, and iPhone 16/Pro class safe areas.

Risks & mitigations:

- Risk: too many controls make voice feel complex.
- Mitigation: show only controls relevant to the current state.

Effort: Medium.

## Phase 8 - Voice Backend Observability

Goal: make production voice failures diagnosable without leaking private transcript content.

Files to modify / create:

- `services/rex-api/app/services/voice_stream_session.py`
- `services/rex-api/app/routes/voice.py`
- `services/rex-api/tests/test_voice_stream_routes.py`
- Deployment runbook docs if useful

Acceptance criteria:

- Unexpected failures log session id, conversation id, client, audio metadata, and error class.
- Logs avoid raw transcript and audio content.
- Readiness confirms Deepgram and Google TTS configuration.
- Tests cover error event shape and safe logging path where practical.

Risks & mitigations:

- Risk: logging sensitive user speech.
- Mitigation: never log raw audio or full transcript in failure logs.

Effort: Small.

## Phase 9 - Voice Release Gate

Goal: verify Voice is stable enough before final Chat/design/release polish.

Files to modify / create:

- `docs/clarity/rex_assistant_polish_plan/06_voice_stability_ux.md`
- `docs/clarity/device_release_checklist.md`

Acceptance criteria:

- Voice controller tests pass.
- Backend voice route and stream tests pass.
- `flutter analyze` passes.
- Manual phone test covers permission, listening, transcript, response, retry, end call, earbuds/Bluetooth, and YouTube/music interruption.
- Remaining voice defects have logs or clear reproduction steps.

Risks & mitigations:

- Risk: voice passes simulator/tests but fails on device.
- Mitigation: require real-device testing before closing this gate.

Effort: Small.
