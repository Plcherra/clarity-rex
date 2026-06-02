# Rex Services Architecture

Last updated: June 1, 2026

## Purpose

This guide documents the post-refactor Rex service structure so future Plaid, Stripe, voice, and memory work does not re-create the old god files.

## Core Backend Services

| Service | Current role |
| --- | --- |
| `chat_service.py` | Public chat facade for non-streaming and streaming turns. It coordinates the extracted services and keeps the chat API stable. |
| `chat_turn_context.py` | Prepares shared chat-turn context: file text, conversation validation/creation, prompt context, accountability signals, and user-message persistence. |
| `chat_context_service.py` | Builds prompt context from conversation history, long-term memory, structured memory, time context, and accountability signals. |
| `rex_brain_chat_service.py` | Owns Rex Brain planning, model kwargs, request ids, metadata, and chat contract application. |
| `memory_turn_service.py` | Owns natural simple-memory confirmation, direct durable save/reject paths, and public message cleanup. |
| `memory_post_turn_service.py` | Owns post-response memory correction handling, memory summaries, and best-effort extraction scheduling. |
| `memory_extraction_service.py` | Stable extraction facade. Parsing, structured normalization, reference resolution, and candidate writing live in focused helpers. |
| `memory_service.py` | Thin compatibility facade over transport, repositories, retrieval, structured CRUD, and candidate/correction CRUD. |

## Core Mobile Memory Files

| File | Current role |
| --- | --- |
| `memory_page.dart` | Memory page shell and UI event wiring. Dialogs, filters, pending review UI, and saved-memory tiles are extracted. |
| `memory_controller.dart` | Provider/state/controller shell. Read, action, and error logic live in controller part files. |
| `memory_api.dart` | Public API facade and shared HTTP transport helpers. Saved, structured, and candidate endpoints live in API part files. |

## Refactor Guardrails

- Keep production files below 500 lines whenever practical.
- Keep public facades stable: `ChatService`, `MemoryService`, `MemoryExtractionService`, `memoryProvider`, and `memoryApiProvider`.
- Extract pure helpers before changing orchestration code.
- Move tests with behavior, not after behavior.
- New Plaid or Stripe work should start in focused service files and integrate through existing facades only after the service has tests.

## Plaid Integration Fit

Plaid transaction ingestion should not go into `chat_service.py` or memory extraction. Prefer a focused service such as `plaid_sync_service.py` for link-token exchange, account sync, transaction fetch, dedupe, and persistence. Rex can then consume summarized financial context through the existing prompt/context path.

## Verification Baseline

Before major feature work:

```bash
cd services/rex-api
python3 -m pytest tests/ -q

cd ../../apps/mobile
flutter analyze
flutter test test/memory_page_test.dart test/memory_page_pending_test.dart test/memory_page_archive_errors_test.dart test/memory_api_test.dart test/memory_label_test.dart test/assistant_navigation_test.dart test/chat_memory_candidate_card_test.dart
```
