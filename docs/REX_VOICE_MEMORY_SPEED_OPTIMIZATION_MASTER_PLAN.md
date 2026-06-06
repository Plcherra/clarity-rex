# Rex Voice Memory Speed Optimization Master Plan

Status: Superseded by `docs/clarity/product/CLARITY_ASSISTANT_INTELLIGENCE_MASTER_PLAN.md`.

This file is retained as historical voice and memory optimization context only.
Current Assistant, memory, voice, and truth-parity work must use the Clarity
Assistant Intelligence plan.

Status: In Progress

Last updated: June 4, 2026

Current cursor: Phase 10 - Final Verification And Manual Voice Tests

## Purpose

Make Rex fast, reliable, and natural, especially in voice. This plan finishes the simplified Rex architecture by removing legacy memory machinery, connecting voice fully to the new direct-memory brain, shrinking prompts, improving memory precision, and reducing latency between the user finishing speech and Rex responding.

The priority is speed and reliability over safety bureaucracy. Rex should feel like a quick, attentive assistant, not a system asking the user to manage backend review queues.

## Core Outcome

By the end of this plan:

- Normal chat and voice turns use one LLM call.
- The active system prompt stays under 900 characters.
- Simple facts save directly after Rex naturally acknowledges them.
- Corrections update existing memory instead of creating duplicates.
- Voice uses speaker output by default and follows the same memory rules as chat.
- Legacy pending candidates, post-turn extraction, and hidden confirmation paths are deleted or fully disabled.
- Voice latency is measured, reduced, and protected by regression tests.

## Non-Goals

- Rebuilding the entire assistant UI.
- Adding vector search or a new memory database.
- Adding complex multi-agent planning.
- Reintroducing pending review cards, approval queues, or background extraction.
- Building a generalized workflow engine for reminders or commitments.

## Current State

| Area | Current State | Risk |
| --- | --- | --- |
| Voice | Voice works but has route/audio-session inconsistencies and still exposes old language in some paths. | Users hear earpiece-style audio, get slow replies, or see voice say it cannot save memory. |
| Memory | Direct saving exists, but legacy candidate/extraction concepts may still be attached in tests, migrations, prompts, or unused files. | Rex may create vague, duplicate, or invisible records. |
| Prompt | The simplified prompt is smaller than before, but the new target is stricter: 900 characters total. | Every voice turn pays unnecessary latency and token cost. |
| Context | Lazy retrieval exists, but recall/update paths need tighter routing and smaller payloads. | Rex may miss saved facts or load irrelevant context. |
| Corrections | Some correction rules exist, but exact replacement behavior is still too pattern-dependent. | Spelling fixes like Somerville or title fixes like "Masters of the Universe" may not update cleanly. |
| Performance | Tests pass, but latency budgets are not yet enforced end to end. | Regressions can creep back in silently. |

## Target State

| Area | Target State | Benefit |
| --- | --- | --- |
| Voice | Voice is the primary path and shares the same direct memory/update logic as chat. | One mental model, fewer bugs. |
| Memory | One durable memory path: direct save/update to long-term memory. | No pending cards, no hidden queues, no confusion. |
| Prompt | One compact base prompt under 900 characters, with tiny optional fragments only when needed. | Faster first token and lower cost. |
| Context | Recent chat by default; targeted memory or goal context only when routed. | Less latency, better relevance. |
| Corrections | User corrections overwrite the best matching old fact. | Clean "What Rex Knows" data. |
| Verification | Tests assert one LLM call, no candidate creation, prompt budget, and voice memory parity. | Stable launch behavior. |

## Phase 1: Cut Legacy Memory Paths From Voice And Chat

Status: Completed on June 4, 2026.

Goal: Remove or fully disable every remaining legacy memory path that can still influence normal chat or voice turns.

Why this matters:

Old pending-candidate and extraction code is the main source of confusing behavior: Rex says it saved something, but the UI shows pending items or nothing at all. Phase 1 makes the runtime path unambiguous before deeper optimization.

Files to change / delete:

- `services/rex-api/app/services/chat_service.py`
- `services/rex-api/app/services/memory_turn_service.py`
- `services/rex-api/app/services/memory_intent_service.py`
- `services/rex-api/app/routes/voice.py`
- `services/rex-api/app/services/voice_stream_config.py`
- `services/rex-api/app/services/voice_stream_session.py`
- Legacy memory candidate, confirmation, review, and extraction files still referenced by active code
- Focused tests under `services/rex-api/tests/`

Steps:

1. Run `rg "MemoryCandidate|memory_candidate|memory-candidates|pending candidate|review session|memory_extraction|post_turn" services/rex-api/app services/rex-api/tests`.
2. Classify every hit as active runtime, dead code, test-only legacy, or migration-only.
3. Delete dead runtime code and remove imports from chat/voice paths.
4. Disable any fallback path that creates review/pending records during normal turns.
5. Update tests so old pending behavior is not expected anywhere in active product behavior.
6. Keep database migration files untouched for now unless they are imported by runtime code.

Done looks like:

- Normal chat and voice cannot create pending candidates.
- No active service imports legacy extraction or candidate code.
- Search results for old terms are limited to archived docs or migration files.

Acceptance criteria and test commands:

- [x] `rg "MemoryCandidate|memory_candidate|memory-candidates|pending candidate|review session|memory_extraction|post_turn" services/rex-api/app` returns no active runtime references.
- [x] `rg "open Chat|open chat|voice though|can't save|cannot save" services/rex-api/app services/rex-api/tests apps/mobile/lib apps/mobile/test` returns no matches.
- [x] `cd services/rex-api && PYTHONPATH=. ./.venv/bin/pytest tests/test_chat_simple_memory_flow.py tests/test_memory_turn_service.py tests/test_voice_routes.py tests/test_voice_stream_routes.py tests/test_chat_service.py -q` passes.
- [x] `cd services/rex-api && PYTHONPATH=. ./.venv/bin/pytest tests -q` passes.

Line count target:

- No changed production file over 500 lines.
- Delete more legacy code than is added.

Line-count ledger:

| File | Before | After | Moved To |
| --- | ---: | ---: | --- |
| `services/rex-api/app/routes/voice.py` | 203 | 203 | N/A |
| `services/rex-api/app/services/voice_stream_config.py` | 30 | 30 | N/A |
| `services/rex-api/tests/test_voice_routes.py` | 480 | 480 | N/A |
| `services/rex-api/tests/test_voice_stream_routes.py` | 323 | 323 | N/A |
| `services/rex-api/tests/test_chat_service.py` | 363 | 363 | N/A |

## Phase 2: Connect Voice To The Same Direct Memory Brain As Chat

Status: Completed on June 4, 2026.

Goal: Make voice and chat use the same direct memory save, update, and recall behavior.

Why this matters:

Voice is the primary interface. If voice says "open chat to save that" or misses updates that chat can handle, Rex feels broken.

Files to change / delete:

- `services/rex-api/app/services/voice_stream_session.py`
- `services/rex-api/app/routes/voice.py`
- `services/rex-api/app/services/memory_turn_service.py`
- `services/rex-api/app/services/memory_intent_service.py`
- `services/rex-api/tests/test_chat_simple_memory_flow.py`
- `services/rex-api/tests/test_voice_stream_routes.py`

Steps:

1. Trace the exact voice turn path from transcript finalization to response generation.
2. Ensure direct memory intent detection runs for voice before or alongside response generation.
3. Remove prompt language that says memory saving is unavailable in voice.
4. Ensure voice memory saves are returned as natural spoken acknowledgments.
5. Add parity tests where the same message saves or updates memory from chat and voice.

Done looks like:

- Voice can save "I live in Somerville."
- Voice can save "I'm watching Masters of the Universe tonight."
- Voice can update "No, Somerville has one o and one m."
- Voice can recall those facts later.

Acceptance criteria and test commands:

- [x] Voice and chat direct memory tests share the same expected durable records.
- [x] No voice prompt contains "open chat" for memory saving.
- [x] `cd services/rex-api && PYTHONPATH=. ./.venv/bin/pytest tests/test_chat_simple_memory_flow.py tests/test_voice_stream_routes.py -q`
- [x] `cd services/rex-api && PYTHONPATH=. ./.venv/bin/pytest tests -q`

Line count target:

- Keep `voice_stream_session.py` under 500 lines or extract a focused helper.

Line-count ledger:

| File | Before | After | Moved To |
| --- | ---: | ---: | --- |
| `services/rex-api/app/services/voice_stream_response_writer.py` | 166 | 171 | N/A |
| `services/rex-api/app/services/voice_stream_session.py` | 385 | 387 | N/A |
| `services/rex-api/tests/voice_stream_fakes.py` | 208 | 217 | N/A |
| `services/rex-api/tests/test_voice_stream_routes.py` | 323 | 445 | N/A |

## Phase 3: Shrink The Active System Prompt Under 900 Characters

Status: Completed on June 4, 2026.

Goal: Enforce a strict 900-character ceiling for the active default Rex prompt.

Why this matters:

Voice latency is sensitive to prompt size. A smaller prompt reduces token cost, model setup time, and prompt conflict.

Files to change / delete:

- `services/rex-api/app/services/prompt_constants.py`
- `services/rex-api/app/services/prompt_service.py`
- `services/rex-api/app/services/rex_brain_prompts.py`
- `services/rex-api/app/services/voice_stream_config.py`
- `services/rex-api/tests/test_prompt_service.py`

Steps:

1. Find every always-on system prompt fragment used by chat and voice.
2. Replace the default prompt with a compact voice-first instruction under 900 characters.
3. Move optional memory, goal, finance, and correction hints behind intent-specific fragments.
4. Add tests that fail if the default prompt exceeds 900 characters.
5. Remove duplicate or conflicting instruction text.

Done looks like:

- Default prompt is short, warm, direct, and non-bureaucratic.
- Memory behavior is handled by code plus tiny intent-specific hints, not giant prompt policy.

Acceptance criteria and test commands:

- [x] Default chat prompt <= 900 characters.
- [x] Default voice prompt <= 900 characters.
- [x] Casual turns do not include memory or goal policy blocks.
- [x] `cd services/rex-api && PYTHONPATH=. ./.venv/bin/pytest tests/test_prompt_service.py -q`

Line count target:

- Remove more prompt text than is added.

Verification:

- Default personality prompt: 364 characters.
- Default personality + guarded memory/action block: 603 characters.
- Voice response instructions: 363 characters.
- Rex Brain layer prompt ceiling: 900 characters.
- Largest Rex Brain layer prompt after shrink: 896 characters.
- Focused prompt/voice tests: `35 passed`.
- Full backend tests: `558 passed`.

Line-count ledger:

| File | Before | After | Moved To |
| --- | ---: | ---: | --- |
| `services/rex-api/app/services/prompt_constants.py` | 27 | 26 | N/A |
| `services/rex-api/app/services/prompt_service.py` | 126 | 131 | N/A |
| `services/rex-api/app/services/rex_brain_prompts.py` | 183 | 144 | N/A |
| `services/rex-api/app/services/voice_stream_config.py` | 30 | 25 | N/A |
| `services/rex-api/tests/test_prompt_service.py` | 642 | 642 | N/A |
| `services/rex-api/tests/test_rex_brain_prompts.py` | 110 | 110 | N/A |
| `services/rex-api/tests/test_voice_stream_routes.py` | 445 | 435 | N/A |

## Phase 4: Improve Specific Memory Capture

Status: Completed on June 4, 2026.

Goal: Save precise facts, titles, dates, amounts, locations, and preferences instead of vague summaries.

Why this matters:

"I will watch a movie" is much less useful than "I plan to watch Masters of the Universe tonight." Rex must preserve the details users actually care about.

Files to change / delete:

- `services/rex-api/app/services/memory_intent_service.py`
- `services/rex-api/app/services/memory_turn_service.py`
- `services/rex-api/app/services/memory_turn_direct_helpers.py`
- `services/rex-api/tests/test_memory_turn_service.py`
- `services/rex-api/tests/test_chat_simple_memory_flow.py`

Steps:

1. Add targeted parsers for common simple facts: name, location, birthday, family relation, plan, movie title, preference, amount, date.
2. Normalize obvious speech recognition errors only when the user intent is clear.
3. Store compact, human-readable memory text plus stable topic fingerprints.
4. Prefer exact user details over assistant paraphrase.
5. Add fixtures for movie titles, date phrases, and location spelling.

Done looks like:

- "Today they released the Masters of the Universe movie. I'm gonna watch." saves the exact title and plan.
- "My mom's birthday is June 18" saves a precise birthday fact.
- "I prefer tea over coffee" saves a precise preference.

Acceptance criteria and test commands:

- [x] Tests assert exact memory content, not vague summaries.
- [x] Direct save does not require a second LLM call.
- [x] `cd services/rex-api && PYTHONPATH=. ./.venv/bin/pytest tests/test_memory_turn_service.py tests/test_chat_simple_memory_flow.py -q`

Line count target:

- Keep `memory_intent_service.py` under 500 lines. Extract focused parsers if needed.

Verification:

- Added exact movie title capture for "Masters of the Universe", including the observed speech-recognition variant "messes of the universe".
- Added direct preference capture for comparisons like "I prefer tea over coffee."
- Unified one-shot `/voice/turn` response instructions with the compact streaming voice instruction constant.
- Focused Phase 4 tests: `52 passed`.
- Full backend tests: `562 passed`.
- Legacy pending/extraction search gates: clean.

Line-count ledger:

| File | Before | After | Moved To |
| --- | ---: | ---: | --- |
| `services/rex-api/app/routes/voice.py` | 203 | 198 | N/A |
| `services/rex-api/app/services/memory_intent_service.py` | 435 | 487 | N/A |
| `services/rex-api/app/services/memory_turn_service.py` | 260 | 260 | N/A |
| `services/rex-api/app/services/memory_turn_direct_helpers.py` | 270 | 270 | N/A |
| `services/rex-api/tests/test_memory_intent_service.py` | 140 | 190 | N/A |
| `services/rex-api/tests/test_memory_turn_service.py` | 247 | 270 | N/A |
| `services/rex-api/tests/test_chat_simple_memory_flow.py` | 437 | 437 | N/A |
| `services/rex-api/tests/test_voice_routes.py` | 480 | 475 | N/A |

## Phase 5: Make Corrections Replace Old Memory Reliably

Status: Completed on June 4, 2026.

Goal: Corrections update or replace the old matching memory record instead of creating duplicates.

Why this matters:

Rex cannot feel trustworthy if "Somerville" and "Summerville" both remain active, or if corrected dates coexist with old dates.

Files to change / delete:

- `services/rex-api/app/services/memory_turn_direct_helpers.py`
- `services/rex-api/app/services/memory_service.py`
- `services/rex-api/app/services/memory_intent_service.py`
- `services/rex-api/tests/test_memory_turn_service.py`
- `services/rex-api/tests/test_memory_retrieval.py`

Steps:

1. Strengthen topic matching for location, birthday, name, job, preference, and plans.
2. Archive or supersede the old fact when a correction is confirmed or clearly stated.
3. Ensure legacy records without topic fingerprints can still be matched.
4. Add tests for spelling corrections, date corrections, and title corrections.
5. Keep the response natural: "Got it, updating that to Somerville, Massachusetts."

Done looks like:

- One active memory per corrected topic.
- Old conflicting memory is inactive or updated.
- "What Rex Knows" shows only the corrected version.

Acceptance criteria and test commands:

- [x] Correction tests prove no duplicate active records.
- [x] Retrieval returns the corrected value only.
- [x] `cd services/rex-api && PYTHONPATH=. ./.venv/bin/pytest tests/test_memory_turn_service.py tests/test_memory_retrieval.py -q`

Line count target:

- Keep helper files under 500 lines.

Verification:

- Strengthened legacy topic matching for name, preference, and personal plan corrections when old records lack topic fingerprints.
- Confirmed Somerville-style location corrections still update in place.
- Confirmed preference reversals update the existing preference instead of creating a second active preference.
- Confirmed movie title corrections update old "Messes Of The Universe" records to "Masters of the Universe."
- Focused memory tests: `29 passed`.
- Chat/voice memory surface tests: `45 passed`.
- Full backend tests: `566 passed`.
- Legacy pending/extraction search gates: clean.

Line-count ledger:

| File | Before | After | Moved To |
| --- | ---: | ---: | --- |
| `services/rex-api/app/services/memory_turn_direct_helpers.py` | 270 | 350 | N/A |
| `services/rex-api/app/services/memory_intent_service.py` | 487 | 487 | N/A |
| `services/rex-api/tests/test_memory_turn_service.py` | 270 | 370 | N/A |
| `services/rex-api/tests/test_memory_retrieval.py` | 682 | 717 | N/A |

## Phase 6: Optimize Voice Latency And Turn Boundaries

Status: Completed on June 4, 2026.

Goal: Reduce the delay between user stopping speech and Rex starting a response.

Why this matters:

Voice feels slow when silence detection, transcription finalization, context loading, or TTS setup takes too long. Rex should feel closer to EchoDesk speed.

Files to change / delete:

- `apps/mobile/lib/features/assistant/voice/data/streaming_audio_capture_service.dart`
- `apps/mobile/lib/features/assistant/voice/data/audio_capture_service.dart`
- `apps/mobile/lib/features/assistant/voice/application/voice_call_controller.dart`
- `services/rex-api/app/services/voice_stream_session.py`
- `services/rex-api/app/services/voice_stream_config.py`
- Voice tests in backend and mobile

Steps:

1. Measure timings for speech finalization, backend response start, TTS start, and playback start.
2. Tune silence thresholds so long thoughts are not cut off too aggressively.
3. Avoid reconnecting or rebuilding audio resources between turns unless required.
4. Skip nonessential context for casual voice turns.
5. Add privacy-safe latency logs.

Done looks like:

- Voice does not cut off normal longer explanations.
- Rex starts responding faster after the user finishes.
- Logs expose where time is spent.

Acceptance criteria and test commands:

- [x] Backend voice logs include timing fields.
- [x] Mobile voice test proves long transcripts are not prematurely discarded.
- [x] `cd services/rex-api && PYTHONPATH=. ./.venv/bin/pytest tests/test_voice_stream_routes.py tests/test_voice_routes.py -q`
- [x] `cd apps/mobile && flutter test test/voice_call_controller_test.dart`

Line count target:

- Extract timing helpers if controllers exceed 500 lines.

Verification:

- Added privacy-safe `voice_turn_timing` backend logs for buffered and live voice turns.
- Timing logs include capture, STT, first Grok token, first TTS audio, total turn, audio bytes, and chunk counts.
- Increased the default endpointing patience from 1.6s to 2.1s so short thinking pauses inside longer speech do not prematurely end the turn.
- Increased max voice utterance duration from 90s to 120s for longer natural explanations.
- Added a mobile endpoint detector regression test for pauses inside long speech.
- Focused backend voice tests: `32 passed`.
- Focused mobile voice tests: `8 passed`.

Line-count ledger:

| File | Before | After | Moved To |
| --- | ---: | ---: | --- |
| `services/rex-api/app/services/voice_stream_session.py` | 387 | 413 | N/A |
| `apps/mobile/lib/features/assistant/voice/data/audio_capture_service.dart` | 238 | 238 | N/A |
| `apps/mobile/lib/features/assistant/voice/data/streaming_audio_capture_service.dart` | 314 | 314 | N/A |
| `services/rex-api/tests/test_voice_stream_routes.py` | 435 | 443 | N/A |
| `apps/mobile/test/voice_call_controller_test.dart` | 418 | 461 | N/A |

## Phase 7: Fix iPhone Audio Routing For Voice Output

Status: Implementation completed on June 4, 2026. Device route verification pending.

Goal: Make Rex voice output use the loud speaker by default, not the earpiece/receiver, while preserving Bluetooth and headphones.

Why this matters:

If Rex sounds like a phone call through the top receiver, the voice experience feels broken and too quiet.

Files to change / delete:

- `apps/mobile/lib/features/assistant/voice/data/audio_session_service.dart`
- `apps/mobile/lib/features/assistant/voice/data/audio_playback_service.dart`
- `apps/mobile/lib/features/assistant/voice/data/text_to_speech_service.dart`
- `apps/mobile/ios/Runner/AppDelegate.swift`
- Optional small iOS platform channel if Dart-level audio session flags are insufficient

Steps:

1. Verify current `defaultToSpeaker` behavior on device.
2. If needed, add a focused iOS platform method to call `overrideOutputAudioPort(.speaker)`.
3. Preserve Bluetooth/headphone route preference when connected.
4. Re-apply speaker routing after interruptions and audio session resets.
5. Add mobile tests where practical and document manual verification.

Done looks like:

- Without earbuds, Rex plays through the bottom loud speaker.
- With earbuds/Bluetooth, Rex respects the selected output device.
- Route does not flip mid-response.

Acceptance criteria and test commands:

- [ ] iPhone manual test confirms loud speaker output after release.
- [ ] Earbuds/Bluetooth manual test confirms selected output is respected after release.
- [x] `cd apps/mobile && flutter analyze lib/features/assistant/voice test/voice_call_controller_test.dart`
- [x] `cd apps/mobile && flutter test test/voice_call_controller_test.dart`

Line count target:

- Any platform channel code must be small and focused.

Verification:

- Added a focused `clarity/voice_audio` iOS platform channel.
- Native iOS now calls `AVAudioSession.overrideOutputAudioPort(.speaker)` when no external output route is active.
- Native iOS preserves Bluetooth, headphones, and AirPlay by clearing the override for those routes.
- Dart audio session service exposes `preferLoudSpeaker()` and calls it after voice session activation.
- Voice controller reapplies speaker preference after lifecycle resume and before cloud/streaming playback.
- Added tests for the native method-channel call and streaming playback speaker preference.
- Focused mobile voice tests: `9 passed`.
- Targeted voice analyzer: no issues.
- Swift parse check: passed.

Line-count ledger:

| File | Before | After | Moved To |
| --- | ---: | ---: | --- |
| `apps/mobile/lib/features/assistant/voice/data/audio_session_service.dart` | 101 | 134 | N/A |
| `apps/mobile/lib/features/assistant/voice/application/voice_call_controller_lifecycle.dart` | 65 | 66 | N/A |
| `apps/mobile/lib/features/assistant/voice/application/voice_call_controller_streaming.dart` | 445 | 447 | N/A |
| `apps/mobile/ios/Runner/AppDelegate.swift` | 16 | 72 | N/A |
| `apps/mobile/test/voice_call_controller_test.dart` | 461 | 486 | N/A |
| `apps/mobile/test/voice_call_controller_test_fakes.dart` | 363 | 372 | N/A |

## Phase 8: Remove Legacy Files And Tighten Module Boundaries

Status: Implementation completed on June 4, 2026.

Goal: Delete unused legacy memory/voice files and keep remaining modules small.

Why this matters:

Dead code creates false paths during debugging and slows future changes. The architecture should make the correct path obvious.

Files to change / delete:

- Any unused `memory_candidate`, `memory_extraction`, `review`, `confirmation`, or old voice helper files
- `services/rex-api/app/services/`
- `services/rex-api/tests/`
- `apps/mobile/lib/features/assistant/`
- `docs/REX_SERVICES_ARCHITECTURE.md`

Steps:

1. Run dead-code and reference searches with `rg`.
2. Delete files with no active imports.
3. Split any newly oversized files.
4. Update architecture docs to describe the simplified runtime path.
5. Run full backend and mobile tests.

Done looks like:

- Active product code has one obvious memory save path.
- No production file exceeds 500 lines without a documented exception.

Acceptance criteria and test commands:

- [x] `rg "MemoryCandidate|memory_candidate|memory-candidates|pending candidate|review session|memory_extraction|post_turn" services/rex-api/app apps/mobile/lib` returns no active code.
- [x] `find services/rex-api/app apps/mobile/lib -type f | xargs wc -l | sort -nr | head -30` reviewed and documented in `docs/REX_SERVICES_ARCHITECTURE.md`.
- [x] `cd services/rex-api && PYTHONPATH=. ./.venv/bin/pytest tests -q`
- [x] `cd apps/mobile && flutter test`
- [x] `cd apps/mobile && flutter analyze lib/features/assistant test/memory_label_test.dart test/voice_call_controller_test.dart`
- [x] `git diff --check`

Line count target:

- All touched source files under 500 lines.

Implementation notes:

- Removed the unused `MemoryDisciplineService` dependency from `ChatService` and FastAPI chat DI. The discipline helper remains only for structured plan/entity/rule policy tests and is no longer attached to normal chat or voice turns.
- Removed dead mobile memory-label helpers for old review-card expected actions and correction previews.
- Updated `docs/REX_SERVICES_ARCHITECTURE.md` with the simplified runtime boundary and documented existing oversized-file exceptions.

Line count ledger:

- `services/rex-api/app/services/chat_service.py`: 381 -> 378.
- `services/rex-api/app/dependencies.py`: 99 -> 94.
- `services/rex-api/tests/test_chat_service.py`: 361 -> 344.
- `services/rex-api/tests/chat_service_fakes.py`: 357 -> 353.
- `apps/mobile/lib/features/assistant/memory/data/memory_labels.dart`: 287 -> 197.
- `docs/REX_SERVICES_ARCHITECTURE.md`: 67 -> 81.

Verification:

- `PYTHONPATH=. ./.venv/bin/pytest tests/test_chat_service.py tests/test_chat_simple_memory_flow.py tests/test_memory_turn_service.py tests/test_voice_routes.py tests/test_voice_stream_routes.py -q` -> 74 passed.
- `flutter test test/memory_label_test.dart test/voice_call_controller_test.dart` -> 15 passed.
- `PYTHONPATH=. ./.venv/bin/pytest tests -q` -> 565 passed.
- `flutter test` -> 125 passed.
- `flutter analyze lib/features/assistant test/memory_label_test.dart test/voice_call_controller_test.dart` -> no issues.
- `git diff --check` -> clean.

## Phase 9: Add Speed Guardrails And One-Call Tests

Status: Completed on June 4, 2026.

Goal: Make performance expectations executable.

Why this matters:

Rex became slow because expensive work was easy to add invisibly. Guardrails prevent accidental reintroduction of second calls, oversized prompts, and eager context loading.

Files to change / delete:

- `services/rex-api/tests/test_chat_service.py`
- `services/rex-api/tests/test_chat_simple_memory_flow.py`
- `services/rex-api/tests/test_prompt_service.py`
- `services/rex-api/tests/test_chat_context_service.py`
- Backend test fakes and fixtures

Steps:

1. Add tests that count LLM calls per normal chat turn.
2. Add tests that count LLM calls per normal voice turn.
3. Add prompt budget tests for chat and voice.
4. Add context budget tests for casual turns.
5. Add no-legacy-term search command to release checklist.

Done looks like:

- A regression that adds a second normal-turn LLM call fails tests.
- A regression that grows the base prompt past 900 characters fails tests.
- A regression that eagerly loads memory/goals for casual voice fails tests.

Acceptance criteria and test commands:

- [x] Normal chat turn test asserts exactly one LLM call.
- [x] Normal voice turn test asserts exactly one LLM call.
- [x] Prompt budget test asserts <= 900 characters.
- [x] `cd services/rex-api && PYTHONPATH=. ./.venv/bin/pytest tests/test_prompt_service.py tests/test_chat_context_service.py tests/test_chat_simple_memory_flow.py tests/test_voice_stream_routes.py -q`

Line count target:

- Split tests by behavior if any test file crosses 500 lines.

Execution notes:

- Added `services/rex-api/tests/test_rex_speed_guardrails.py` to enforce one-call normal chat, streaming chat, normal voice, normal voice WebSocket, prompt budgets, lazy casual context, and no active product-code legacy memory candidate terms.
- Split prompt context budget and trimming tests out of `services/rex-api/tests/test_prompt_service.py` into `services/rex-api/tests/test_prompt_context_budgets.py`.
- Preserved existing prompt behavior tests while reducing the oversized prompt test file below the 500-line project standard.

Line count ledger:

- `services/rex-api/tests/test_prompt_service.py`: 642 -> 401.
- `services/rex-api/tests/test_prompt_context_budgets.py`: 0 -> 251.
- `services/rex-api/tests/test_rex_speed_guardrails.py`: 0 -> 162.

Verification:

- `PYTHONPATH=. ./.venv/bin/pytest tests/test_rex_speed_guardrails.py tests/test_prompt_service.py tests/test_prompt_context_budgets.py tests/test_chat_context_service.py tests/test_chat_service.py tests/test_chat_simple_memory_flow.py tests/test_voice_stream_routes.py -q` -> 77 passed.
- `rg -n "MemoryCandidate|memory_candidate|pending candidate|review session|confirmation record" services/rex-api/app apps/mobile/lib` -> no matches.
- `git diff --check` -> clean.
- `PYTHONPATH=. ./.venv/bin/pytest tests -q` -> 571 passed.

## Phase 10: Final Verification And Manual Voice Tests

Goal: Verify the full voice-first experience on device before calling the plan complete.

Why this matters:

The final truth is the phone. Backend tests can prove the flow, but speaker routing, turn-taking, and natural memory feel must be verified manually.

Files to change / delete:

- `docs/REX_VOICE_MEMORY_SPEED_OPTIMIZATION_MASTER_PLAN.md`
- `docs/REX_SERVICES_ARCHITECTURE.md`
- Release checklist docs if needed

Steps:

1. Run full backend tests.
2. Run full mobile tests and analysis.
3. Restart VPS backend.
4. Release the mobile app to the phone.
5. Run manual voice test scenarios.
6. Record results and mark this plan complete only if acceptance criteria pass.

Done looks like:

- Voice is loud and correctly routed.
- Rex saves simple facts directly in voice.
- Rex updates corrected facts directly in voice.
- Rex recalls saved facts.
- No pending memory cards appear.
- Normal turns feel faster than before.

Acceptance criteria and test commands:

- [ ] `cd services/rex-api && PYTHONPATH=. ./.venv/bin/pytest tests -q`
- [ ] `cd apps/mobile && flutter analyze`
- [ ] `cd apps/mobile && flutter test`
- [ ] `./scripts/vps_restart_rex_api.sh`
- [ ] `./scripts/mobile_release_run.sh`
- [ ] Manual: ask voice "I live in Somerville, Massachusetts."
- [ ] Manual: ask voice "What do you know about where I live?"
- [ ] Manual: correct voice "Actually Somerville has one o and one m."
- [ ] Manual: ask voice "I plan to watch Masters of the Universe tonight."
- [ ] Manual: ask chat "What am I watching tonight?"
- [ ] Manual: verify "Knows" tab shows saved facts and no pending items.

Line count target:

- No implementation work unless manual tests reveal a blocker.

## Verification Commands

Backend:

```bash
cd services/rex-api
PYTHONPATH=. ./.venv/bin/pytest tests -q
```

Mobile:

```bash
cd apps/mobile
flutter analyze
flutter test
```

Search gates:

```bash
rg "MemoryCandidate|memory_candidate|memory-candidates|pending candidate|review session|memory_extraction|post_turn" services/rex-api/app apps/mobile/lib
```

Release:

```bash
./scripts/vps_restart_rex_api.sh
./scripts/mobile_release_run.sh
```

## Execution Order

1. Phase 1 - Cut Legacy Memory Paths From Voice And Chat
2. Phase 2 - Connect Voice To The Same Direct Memory Brain As Chat
3. Phase 3 - Shrink The Active System Prompt Under 900 Characters
4. Phase 4 - Improve Specific Memory Capture
5. Phase 5 - Make Corrections Replace Old Memory Reliably
6. Phase 6 - Optimize Voice Latency And Turn Boundaries
7. Phase 7 - Fix iPhone Audio Routing For Voice Output
8. Phase 8 - Remove Legacy Files And Tighten Module Boundaries
9. Phase 9 - Add Speed Guardrails And One-Call Tests
10. Phase 10 - Final Verification And Manual Voice Tests

## Release Gate

Ship only when:

- [ ] Full backend tests pass.
- [ ] Full mobile tests pass.
- [ ] Normal chat and voice use exactly one LLM call.
- [ ] Active system prompt is under 900 characters.
- [ ] No pending memory candidate code exists in active product paths.
- [ ] Voice speaker routing is verified on iPhone.
- [ ] Simple memory save, correction, and recall work in voice.
- [ ] "Knows" tab contains saved facts only.
- [ ] Manual voice smoke test passes on device.
