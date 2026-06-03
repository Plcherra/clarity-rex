# Rex Services Architecture

Last updated: June 3, 2026

## Purpose

This root-level guide documents the post-refactor Rex service structure so future Plaid, Stripe, voice, and memory work does not re-create the old god files. It mirrors the canonical Rex architecture notes previously kept under `docs/clarity/rex_assistant_polish_plan/`.

## Core Backend Services

| Service | Current role |
| --- | --- |
| `chat_service.py` | Public chat facade for non-streaming and streaming turns. It coordinates extracted services and keeps the chat API stable. |
| `chat_turn_context.py` | Prepares shared chat-turn context: file text, conversation validation/creation, prompt context, accountability signals, and user-message persistence. |
| `chat_context_service.py` | Builds prompt context from conversation history, long-term memory, structured memory, time context, and accountability signals. |
| `rex_brain_chat_service.py` | Owns Rex Brain planning, model kwargs, request ids, metadata, and chat contract application. |
| `memory_turn_service.py` | Owns natural simple-memory confirmation, direct durable save/reject paths, and public message cleanup. |
| `memory_post_turn_service.py` | Owns post-response memory correction handling, memory summaries, and best-effort extraction scheduling. |
| `memory_extraction_service.py` | Stable extraction facade. Parsing, structured normalization, reference resolution, and candidate writing live in focused helpers. |
| `memory_service.py` | Compatibility facade over transport, repositories, retrieval, structured CRUD, and candidate/correction CRUD. |
| `voice_stream_session.py` | Backend voice WebSocket session orchestration. Capture, planning, response streaming, playback coordination, and shutdown are delegated where practical. |
| `plaid_sync_service.py` | Fail-closed Plaid service skeleton. It documents the boundary and prevents Plaid work from leaking into chat or memory services before runtime integration is approved. |

## Core Mobile Rex Files

| File | Current role |
| --- | --- |
| `memory_page.dart` | Memory page shell and UI event wiring. Dialogs, filters, pending review UI, and saved-memory tiles are extracted. |
| `memory_controller.dart` | Provider/state/controller shell. Read, action, and error logic live in controller part files. |
| `memory_api.dart` | Public API facade and shared HTTP transport helpers. Saved, structured, and candidate endpoints live in API part files. |
| `voice_call_controller.dart` | Voice controller facade. Lifecycle, capture, playback, transcript, and streaming helpers are split into focused part files. |
| `chat_page.dart` | Chat UI shell. Still a follow-up cleanup candidate because it remains over the preferred file-size limit. |

## Refactor Guardrails

- Keep production files below 500 lines whenever practical.
- Keep public facades stable: `ChatService`, `MemoryService`, `MemoryExtractionService`, `memoryProvider`, and `memoryApiProvider`.
- Extract pure helpers before changing orchestration code.
- Move tests with behavior, not after behavior.
- New Plaid or Stripe work should start in focused service files and integrate through existing facades only after the service has tests.

## Known Follow-Up Areas

- `prompt_service.py` and `rex_brain_context.py` remain backend cleanup targets.
- Budget, accountability, transaction, dashboard, and chat mobile files still exceed the preferred file-size limit.
- Broad backend exception handlers need a circuit-breaker ledger so intentional degraded behavior is separate from hidden bugs.
- Voice long-form input still needs final device validation.

## Plaid Integration Fit

Plaid transaction ingestion should not go into `chat_service.py`, memory extraction, dashboard widgets, or CSV import files. Prefer focused services for link-token exchange, account sync, transaction fetch, dedupe, and persistence. Rex should consume summarized financial context through the existing financial read-model and prompt/context path.

## Verification Baseline

Before major feature work:

```bash
cd services/rex-api
.venv/bin/python -m pytest tests -q

cd ../../apps/mobile
flutter analyze
flutter test

cd ../web
npm run build
```
