# Rex Voice Memory Reliability Recovery Plan

Status: Phase 9 complete

Last updated: June 4, 2026

Current cursor: Phase 10 - Device Validation And Release Checklist

## Executive Summary

Rex voice is not reliable enough yet. The current implementation has the right simplified direction, but manual testing shows two critical failures:

- Voice still feels slow, pauses between spoken phrases, cuts long speech, and sometimes fails on empty or partial audio.
- Voice is not reliably connected to Rex's durable knowledge. It misses saved facts like location, stores vague plans like "watch it tonight," and does not consistently update corrected memories.

The root cause is not one bug. It is a chain:

1. Voice turn-taking is client-ended on iOS, so long speech can be cut or split too early.
2. TTS is generated in blocking chunks, which can cause pauses between phrases.
3. Memory recall is gated by a narrow intent router that misses natural questions like "where am I located?" or "do you know anything about me?"
4. Direct memory extraction is too pattern-specific, so movie titles, plans, corrections, and location updates are sometimes vague or missed.
5. Voice does not have a single verified contract that proves it can save, update, and recall the same facts as chat.

This plan replaces patching-by-symptom with a focused recovery path. The goal is a voice-first Rex that is fast, handles longer speech naturally, and uses the same durable memory and goals system as chat.

## Non-Negotiables

- Voice is the primary interface.
- Normal voice and chat turns use one LLM call.
- No pending memory cards or hidden approval flows.
- Simple facts save directly after natural acknowledgement.
- Corrections update or replace existing memory.
- Memory recall must work from voice for identity, location, people, dates, plans, preferences, and recent personal events.
- Voice should not claim it does not know facts already visible in What Rex Knows.
- Tests must cover the exact failures from manual testing.

## Current Failure Evidence

| Symptom | Likely Code Cause | Files |
| --- | --- | --- |
| "Do you know where I'm located?" returns no saved location. | Router does not treat "located", "city", "about me", or similar phrasing as memory recall. | `services/rex-api/app/services/rex_intent_router.py` |
| "Masters of the Universe tonight" saved as "watch it tonight." | Direct memory patterns lose the title when the object appears before "watch it" or when transcript uses "it." | `services/rex-api/app/services/memory_intent_service.py` |
| Location correction says it is fixed but memory remains old. | Correction/upsert matching depends on narrow topic fingerprints and old content matching. | `services/rex-api/app/services/memory_turn_direct_helpers.py` |
| Voice cuts long thoughts. | Mobile endpoint detector sends `utterance.end` after silence and server requires explicit iOS utterance end. | `apps/mobile/lib/features/assistant/voice/data/streaming_audio_capture_service.dart`, `services/rex-api/app/services/voice_stream_live_transcription.py` |
| Voice pauses while speaking. | TTS is synthesized chunk-by-chunk and each chunk blocks before audio is sent. | `services/rex-api/app/services/voice_stream_response_writer.py` |
| Empty speech creates disruptive errors. | No-speech and endpoint timers complete as false and show an error instead of silently re-listening. | `apps/mobile/lib/features/assistant/voice/application/voice_call_controller_streaming.dart` |

## Phase 1: Build A Voice Failure Trace

Goal:

Add targeted logging and tests that prove where voice latency and memory misses occur.

Why this matters:

We need to stop guessing. Before changing thresholds and prompts again, every voice turn should expose sanitized timing, intent decision, context loaded, memory action, and TTS chunk timing.

Files to change:

- `services/rex-api/app/services/voice_stream_session.py`
- `services/rex-api/app/services/voice_stream_response_writer.py`
- `services/rex-api/app/services/rex_intent_router.py`
- `services/rex-api/app/services/memory_turn_service.py`
- `services/rex-api/tests/test_voice_stream_routes.py`
- `services/rex-api/tests/test_rex_speed_guardrails.py`

What Done Looks Like:

- Voice logs include STT final time, first token time, first audio time, total TTS chunk count, intent, loaded context flags, and memory action.
- Tests reproduce the user examples without requiring manual device testing.
- No sensitive raw audio or tokens are logged.

Completion Notes:

- Completed June 4, 2026.
- Added opt-in `turn.trace` events for voice streams only.
- Voice timing logs now include context flags, memory action, TTS chunk count, and total TTS time.
- Added focused fixtures for location recall, exact movie-plan memory, and location correction.
- Acceptance command passed: `21 passed in 0.28s`.

Acceptance Criteria:

- `cd services/rex-api && PYTHONPATH=. ./.venv/bin/pytest tests/test_voice_stream_routes.py tests/test_rex_speed_guardrails.py -q`
- A test fixture covers: "Do you know where I'm located?", "Masters of the Universe tonight", and "fix my location to Somerville with one o and one m."
- Logs make it clear whether a failure is STT, routing, memory, LLM, TTS, or mobile playback.

Line Count Target:

- Keep all changed production files under 500 lines.
- Add small helper functions instead of large inline logging blocks.

## Phase 2: Fix Voice Memory Recall Routing

Goal:

Make voice load the right long-term memory for natural recall questions.

Why this matters:

Rex cannot say "I do not know your location" when What Rex Knows already has the location. This is a trust-breaking bug.

Files to change:

- `services/rex-api/app/services/rex_intent_router.py`
- `services/rex-api/app/services/chat_context_service.py`
- `services/rex-api/app/services/memory_retrieval_ranker.py`
- `services/rex-api/tests/test_rex_intent_router.py`
- `services/rex-api/tests/test_memory_retrieval.py`
- `services/rex-api/tests/test_voice_stream_routes.py`

What Done Looks Like:

- "Where am I located?", "what city do I live in?", "do you know anything about me?", "what are my plans tonight?", and "do you know my mom's birthday?" route to memory recall.
- Voice recall loads profile and long-term memory using the same path as chat.
- Recall answers cite saved facts instead of asking the user to re-enter them.

Completion Notes:

- Completed June 4, 2026.
- Broadened memory recall routing for natural voice phrases: location, city, profile/about-me, plans tonight, and family birthdays.
- Expanded retrieval concepts so "anything about me" triggers profile recall, and "located/plans/tonight" connect to saved location and recent plan memories.
- Added a voice route test proving saved memory is inserted into the real chat prompt for location, movie-plan, and mom-birthday recall.
- Acceptance command passed: `47 passed in 0.27s`.

Acceptance Criteria:

- Voice recalls saved location from existing memory.
- Voice recalls saved movie/night plan from existing memory.
- Voice recalls person/date memories.
- `cd services/rex-api && PYTHONPATH=. ./.venv/bin/pytest tests/test_rex_intent_router.py tests/test_memory_retrieval.py tests/test_voice_stream_routes.py -q`

Line Count Target:

- `rex_intent_router.py` stays under 400 lines.

## Phase 3: Make Direct Memory Capture Exact

Goal:

Capture specific details from voice and chat instead of vague summaries.

Why this matters:

"User plans to watch it tonight" is not useful memory. Rex must save exact details like "User plans to watch Masters of the Universe tonight" and "User bought tickets."

Files to change:

- `services/rex-api/app/services/memory_intent_service.py`
- `services/rex-api/app/services/personal_plan_intent_parser.py`
- `services/rex-api/app/services/memory_turn_service.py`
- `services/rex-api/app/services/memory_turn_direct_helpers.py`
- `services/rex-api/tests/test_chat_simple_memory_flow.py`
- `services/rex-api/tests/test_voice_stream_routes.py`

What Done Looks Like:

- Movie/title extraction handles title-before-action, action-before-title, "it" references from recent context, and common transcription errors.
- Plans capture date/time, title, amount, and cancellation when present.
- Rex does not save vague "it" memories when a specific title is available.

Completion Notes:

- Completed June 4, 2026.
- Extracted exact personal-plan parsing into `personal_plan_intent_parser.py` so `memory_intent_service.py` stays focused and under the 500-line limit.
- Personal plan memories now use a stable title-based topic fingerprint, so ticket updates and cancellations update the same durable memory.
- Removed the movie-specific hardcoded fallback from plan topic matching and replaced it with metadata/title matching plus generic overlap fallback.
- Acceptance command passed: `54 passed in 0.30s`.
- Line counts: `memory_intent_service.py` 441 lines, `personal_plan_intent_parser.py` 171 lines, `memory_turn_direct_helpers.py` 355 lines.

Acceptance Criteria:

- "They just released Masters of the Universe, and I'm gonna watch it tonight" saves the exact title.
- "I already bought the tickets" updates the same plan instead of creating a vague second memory.
- "I gotta cancel that because my money is tight" updates the saved plan with cancellation context.
- `cd services/rex-api && PYTHONPATH=. ./.venv/bin/pytest tests/test_chat_simple_memory_flow.py tests/test_voice_stream_routes.py -q`

Line Count Target:

- If `memory_intent_service.py` would exceed 500 lines, extract `personal_plan_intent_parser.py`.

## Phase 4: Make Corrections Replace Existing Facts

Goal:

Make corrections reliably update old durable memory instead of creating duplicates or only saying they updated.

Why this matters:

Corrections are where users learn whether Rex is trustworthy. If Rex says "fixing it" and the old fact remains, the memory system feels fake.

Files to change:

- `services/rex-api/app/services/memory_turn_direct_helpers.py`
- `services/rex-api/app/services/memory_intent_service.py`
- `services/rex-api/app/services/memory_service.py`
- `services/rex-api/tests/test_memory_turn_service.py`
- `services/rex-api/tests/test_chat_simple_memory_flow.py`

What Done Looks Like:

- Location corrections overwrite the existing location memory by topic, not by exact old sentence.
- Title/date/amount corrections update the existing plan or event memory.
- Rex's response is based on actual update success, not intent assumption.

Completion Notes:

- Completed June 4, 2026.
- Added direct parsing for natural correction phrases like "I don't live in Summerville. It's Somerville with one o and one m."
- Added direct parsing for family birthday corrections without requiring the "my" prefix, such as "No, mom's birthday is June 28."
- Durable updates now fail visibly if storage returns no updated record; Rex no longer claims a correction was saved unless the update actually succeeds.
- Acceptance command passed: `44 passed in 0.19s`.
- Line counts: `memory_intent_service.py` 467 lines, `memory_turn_direct_helpers.py` 392 lines, `test_memory_turn_service.py` 469 lines.

Acceptance Criteria:

- "I don't live in Summerville. It's Somerville with one o and one m" updates `fact:identity:location`.
- "No, mom's birthday is June 28" replaces the prior mom birthday fact.
- Tests assert one active memory remains for each corrected topic.
- `cd services/rex-api && PYTHONPATH=. ./.venv/bin/pytest tests/test_memory_turn_service.py tests/test_chat_simple_memory_flow.py -q`

Line Count Target:

- Extract correction matching helpers if any file approaches 500 lines.

## Phase 5: Attach Voice To Goals And Commitments

Goal:

Make voice understand and recall goals, commitments, reminders, and plan changes without adding bureaucracy.

Why this matters:

Voice should support natural statements like "I need to send her $200 on the 10th" or "money is tight, cancel the movie" and connect them to goals/commitments when appropriate.

Files to change:

- `services/rex-api/app/services/rex_intent_router.py`
- `services/rex-api/app/services/goal_command_service.py`
- `services/rex-api/app/services/chat_context_service.py`
- `services/rex-api/app/services/voice_stream_response_writer.py`
- `services/rex-api/tests/test_goal_command_service.py`
- `services/rex-api/tests/test_voice_stream_routes.py`

What Done Looks Like:

- Voice can create or update simple commitments when the user explicitly asks.
- Voice can recall current commitments and goals.
- Voice does not claim reminders are set unless the backend actually created a record.

Completion Notes:

- Completed June 4, 2026.
- Expanded direct goal/commitment handling for natural reminder language such as "set a reminder to..." and "I need/gotta..." with due dates.
- Added truthful save-failure fallbacks so Rex no longer claims a commitment or goal was saved when the backend write fails.
- Added focused goal-command tests and a real voice WebSocket command test proving explicit commitment requests complete without any LLM call.
- Acceptance commands passed:
  - `PYTHONPATH=. ./.venv/bin/pytest tests/test_goal_command_service.py tests/test_voice_stream_routes.py -q`
  - `PYTHONPATH=. ./.venv/bin/pytest tests/test_goal_command_service.py tests/test_voice_goal_command_flow.py -q`
- Line counts: `goal_command_service.py` 446 lines, `test_goal_command_service.py` 149 lines, `test_voice_goal_command_flow.py` 78 lines. `test_voice_stream_routes.py` remains 516 lines from earlier phases and was not expanded in this phase.

Acceptance Criteria:

- "Remind me to send her $200 on the 10th" creates a commitment or truthful fallback.
- "What are my plans tonight?" can answer from saved plan memory or goal context.
- "Cancel that movie plan" updates the plan/event memory or asks one concise clarification.
- `cd services/rex-api && PYTHONPATH=. ./.venv/bin/pytest tests/test_goal_command_service.py tests/test_voice_stream_routes.py -q`

Line Count Target:

- No new large orchestration service.

## Phase 6: Rework Mobile Voice Endpointing For Long Speech

Goal:

Stop cutting users off during longer voice thoughts while keeping voice responsive.

Why this matters:

Dream explanations, emotional context, financial explanations, and natural speech have pauses. Rex must wait long enough without making short turns feel slow.

Files to change:

- `apps/mobile/lib/features/assistant/voice/data/audio_capture_service.dart`
- `apps/mobile/lib/features/assistant/voice/data/streaming_audio_capture_service.dart`
- `apps/mobile/lib/features/assistant/voice/application/voice_call_controller_streaming.dart`
- `apps/mobile/test/voice_endpoint_detector_test.dart`
- `apps/mobile/test/voice_call_controller_test.dart`

What Done Looks Like:

- Long utterances can include short pauses without ending early.
- Empty/no-speech turns quietly return to listening unless the user explicitly expects feedback.
- Endpoint behavior is tested with multiple pause durations.

Completion Notes:

- Completed June 4, 2026.
- Increased default and streaming endpoint silence windows to 3.2 seconds so natural pauses do not split longer thoughts.
- Increased the no-speech timeout to 12 seconds and changed empty turns from a blocking failed state to quiet re-listening.
- Raised the speech-start force-endpoint guard from 8 seconds to 90 seconds so long explanations are not cut off by the old short timer.
- Removed the empty-turn failure counter and provider from the streaming voice controller.
- Added endpoint coverage for a 20-40 second utterance with repeated 2.5 second pauses.
- Updated no-speech and inactive lifecycle tests to prove the call stays recoverable without a red error card.
- Acceptance command passed: `cd apps/mobile && flutter test test/voice_call_controller_test.dart`.
- Note: there is no separate `test/voice_endpoint_detector_test.dart`; endpoint detector coverage currently lives in `test/voice_call_controller_test.dart`.
- Line counts: `audio_capture_service.dart` 238, `streaming_audio_capture_service.dart` 314, `voice_call_controller.dart` 402, `voice_call_controller_commands.dart` 177, `voice_call_controller_providers.dart` 110, `voice_call_controller_timers.dart` 330, `voice_call_controller_test.dart` 529.

Acceptance Criteria:

- A simulated 20-40 second utterance with 1.5-2.5 second pauses does not split too early.
- No-speech timeout does not leave a blocking red error card during an active call.
- `cd apps/mobile && flutter test test/voice_endpoint_detector_test.dart test/voice_call_controller_test.dart`

Line Count Target:

- Keep endpointing logic inside detector/service tests, not UI widgets.

## Phase 7: Reduce Spoken Response Pauses

Goal:

Make Rex's spoken audio feel continuous and quick.

Why this matters:

Even if first response is fast, pauses between phrases make Rex feel broken. TTS chunking needs to be optimized for speech continuity.

Files to change:

- `services/rex-api/app/services/voice_stream_response_writer.py`
- `services/rex-api/app/services/google_tts_service.py`
- `apps/mobile/lib/features/assistant/voice/data/audio_playback_service.dart`
- `apps/mobile/lib/features/assistant/voice/data/streaming_audio_playback_queue.dart`
- `apps/mobile/test/voice_playback_service_test.dart`
- `services/rex-api/tests/test_voice_stream_routes.py`
- `services/rex-api/tests/test_voice_tts_chunking.py`

What Done Looks Like:

- TTS chunks are buffered or queued so playback does not pause between sentences.
- First audio starts quickly, but later chunks are prepared ahead when possible.
- Very short fragments are not sent to TTS as separate audio unless needed.

Completion Notes:

- Completed June 4, 2026.
- Raised the minimum punctuation split from short phrase fragments to 80 characters and the forced split limit to 220 characters so Rex does not send tiny clauses like "Cool." as standalone TTS requests.
- Added focused backend chunking tests for short fragments, substantial sentence boundaries, and long text without punctuation.
- Added mobile streaming playback queue tests proving chunks play sequentially, drain after the final chunk, and cancel/ignore late chunks cleanly.
- Acceptance commands passed:
  - `PYTHONPATH=. ./.venv/bin/pytest tests/test_voice_stream_routes.py tests/test_voice_tts_chunking.py -q`
  - `flutter test test/voice_playback_service_test.dart`
- Note: the active mobile playback implementation is split between `audio_playback_service.dart` and `streaming_audio_playback_queue.dart`; there is no separate `voice_playback_service.dart` production file.
- Line counts: `voice_stream_response_writer.py` 205, `google_tts_service.py` 238, `audio_playback_service.dart` 88, `streaming_audio_playback_queue.dart` 161, `voice_playback_service_test.dart` 137, `test_voice_tts_chunking.py` 41.

Acceptance Criteria:

- Backend test asserts TTS chunk count is reasonable for short replies.
- Playback service queues chunks without gaps where possible.
- Voice timing logs show first audio and total audio generation timing.
- `cd services/rex-api && PYTHONPATH=. ./.venv/bin/pytest tests/test_voice_stream_routes.py -q`
- `cd apps/mobile && flutter test test/voice_playback_service_test.dart`

Line Count Target:

- Keep `voice_stream_response_writer.py` under 250 lines.

## Phase 8: Add Voice Memory Parity Tests

Goal:

Create a focused test suite that proves voice and chat have the same memory behavior.

Why this matters:

Every prior failure came back because only happy-path chat behavior was protected. Voice needs its own parity contract.

Files to change:

- `services/rex-api/tests/test_voice_memory_parity.py`
- `services/rex-api/tests/test_chat_simple_memory_flow.py`
- `services/rex-api/tests/voice_stream_fakes.py`
- `apps/mobile/test/voice_call_controller_test.dart`

What Done Looks Like:

- Exact user examples from screenshots are covered.
- Tests prove durable memory save, update, and recall from voice.
- Tests fail if Rex returns "I do not know" for saved What Rex Knows data.

Completion Notes:

- Completed June 4, 2026.
- Added `test_voice_memory_parity.py` to lock voice behavior for exact movie plan save/update/cancel, location correction and recall, mom birthday save and recall, and profile/plan/location recall.
- Voice parity tests assert direct durable memory behavior and reject pending/candidate language in voice memory events.
- `_voice_turn` now fails fast on websocket error events so future regressions do not hide as test hangs.
- Acceptance command passed: `PYTHONPATH=. ./.venv/bin/pytest tests/test_voice_memory_parity.py tests/test_voice_stream_routes.py -q`.
- Line counts: `test_voice_memory_parity.py` 249, `voice_stream_fakes.py` 233. `test_voice_stream_routes.py` remains 516 from prior coverage and was not expanded in this phase.

Acceptance Criteria:

- Voice saves exact movie title.
- Voice updates location spelling.
- Voice recalls location, mom birthday, and current plan.
- Voice creates no pending cards or legacy candidate records.
- `cd services/rex-api && PYTHONPATH=. ./.venv/bin/pytest tests/test_voice_memory_parity.py tests/test_voice_stream_routes.py -q`

Line Count Target:

- Keep each test file under 500 lines.

## Phase 9: Add Speed Budgets And One-Call Guardrails

Goal:

Protect voice latency and prevent the old hidden second-call behavior from returning.

Why this matters:

Rex should keep getting faster. Guardrails prevent regressions when memory, goals, or Plaid context are added.

Files to change:

- `services/rex-api/tests/test_rex_speed_guardrails.py`
- `services/rex-api/tests/test_prompt_context_budgets.py`
- `services/rex-api/app/services/chat_service.py`
- `services/rex-api/app/services/voice_stream_response_writer.py`

What Done Looks Like:

- Normal voice turns use one model call.
- Prompt and context budgets are enforced.
- TTS and STT timing metadata is asserted in tests.

Completion Notes:

- Completed June 4, 2026.
- Added explicit prompt-shape guardrails proving casual voice/chat turns use only the tiny default prompt and latest user message.
- Added one-call voice recall guardrails proving recall turns stay to one LLM call with bounded memory/structured context lookups.
- Added websocket timing assertions for STT, total turn, first audio, total TTS, and TTS chunk count.
- Added active product code scans that fail if legacy pending-candidate terms or second-call memory extraction hooks return.
- Acceptance commands passed:
  - `PYTHONPATH=. ./.venv/bin/pytest tests/test_rex_speed_guardrails.py tests/test_prompt_context_budgets.py -q`
  - `PYTHONPATH=. ./.venv/bin/pytest tests/test_chat_service.py tests/test_voice_stream_routes.py tests/test_voice_memory_parity.py -q`
- Active product scan returned no hits for: `memory_post_turn`, `memory_extraction`, `extract_memory_after_success`, `extract_memory`, `MemoryCandidate`, `memory_candidate`, `pending candidate`, `review session`, or `confirmation record`.
- Line counts: `test_rex_speed_guardrails.py` 325, `test_prompt_context_budgets.py` 290. Production files did not grow: `chat_service.py` 398, `voice_stream_response_writer.py` 205.

Acceptance Criteria:

- Casual voice prompt stays under 900 characters.
- Normal voice path does not call memory extraction or a second LLM.
- Context payload stays small unless memory/goal recall is explicitly routed.
- `cd services/rex-api && PYTHONPATH=. ./.venv/bin/pytest tests/test_rex_speed_guardrails.py tests/test_prompt_context_budgets.py -q`

Line Count Target:

- No production file grows by more than 80 lines.

## Phase 10: Device Validation And Release Checklist

Goal:

Validate the fixed voice experience on a real iPhone before calling it done.

Why this matters:

Voice issues are partly device/audio-session issues. Passing backend tests is not enough.

Files to change:

- `docs/REX_VOICE_MEMORY_RELIABILITY_RECOVERY_PLAN.md`
- Any release checklist docs already used for Rex/manual testing

What Done Looks Like:

- A repeatable manual script verifies speed, long speech, memory save, memory update, memory recall, goals, speaker routing, and no-speech recovery.
- The VPS restart and mobile release commands are documented next to the checklist.

Acceptance Criteria:

- On device, Rex speaks through the loudspeaker unless headphones/Bluetooth are selected.
- Rex can listen to a long dream explanation without cutting off prematurely.
- Rex saves "Masters of the Universe tonight" with the exact title.
- Rex updates "Somerville, Massachusetts" with the corrected spelling.
- Rex answers "Where am I located?" from What Rex Knows.
- Rex answers "What are my plans tonight?" from saved plan/goals.
- Empty silence returns to listening without a scary blocking error.
- Backend logs show no hidden second LLM calls on normal turns.

Manual Release Commands:

```bash
ssh rex@209.126.87.50
cd /opt/clarity/current
git pull
./scripts/vps_restart_rex_api.sh
sudo journalctl -u clarity-rex.service --since "10 minutes ago" --no-pager -l
```

```bash
cd /Users/pedromartins/Desktop/clarity-rex
./scripts/mobile_release_run.sh
```

Line Count Target:

- Documentation-only unless test fixes are needed.

## Execution Order

1. Phase 1: Build A Voice Failure Trace
2. Phase 2: Fix Voice Memory Recall Routing
3. Phase 3: Make Direct Memory Capture Exact
4. Phase 4: Make Corrections Replace Existing Facts
5. Phase 5: Attach Voice To Goals And Commitments
6. Phase 6: Rework Mobile Voice Endpointing For Long Speech
7. Phase 7: Reduce Spoken Response Pauses
8. Phase 8: Add Voice Memory Parity Tests
9. Phase 9: Add Speed Budgets And One-Call Guardrails
10. Phase 10: Device Validation And Release Checklist
