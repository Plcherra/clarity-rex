# Rex Services Architecture

Last updated: June 4, 2026

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
| `memory_service.py` | Compatibility facade over transport, repositories, retrieval, structured CRUD, corrections, and direct durable memory writes. |
| `memory_discipline_service.py` | Structured plan/entity/rule policy helper only. It is no longer injected into normal chat or voice turns. |
| `voice_stream_session.py` | Backend voice WebSocket session orchestration. Capture, planning, response streaming, playback coordination, and shutdown are delegated where practical. |
| `plaid_sync_service.py` | Fail-closed Plaid service skeleton. It documents the boundary and prevents Plaid work from leaking into chat or memory services before runtime integration is approved. |

## Core Mobile Rex Files

| File | Current role |
| --- | --- |
| `memory_page.dart` | "What Rex Knows" page shell and UI event wiring. Dialogs, filters, and saved-memory tiles are extracted. |
| `memory_controller.dart` | Provider/state/controller shell. Read, action, and error logic live in controller part files. |
| `memory_api.dart` | Public API facade and shared HTTP transport helpers for saved and structured memory. |
| `voice_call_controller.dart` | Voice controller facade. Lifecycle, capture, playback, transcript, and streaming helpers are split into focused part files. |
| `chat_page.dart` | Chat UI shell. Still a follow-up cleanup candidate because it remains over the preferred file-size limit. |

## Refactor Guardrails

- Keep production files below 500 lines whenever practical.
- Keep public facades stable: `ChatService`, `MemoryService`, `memoryProvider`, and `memoryApiProvider`.
- Normal chat and voice turns must not run post-turn memory extraction or a second LLM call. Durable memory writes flow through `memory_turn_service.py`.
- Pending memory review tables are legacy-only. Product code must not import, route to, render, or recreate pending memory review flows.
- Structured memory policy helpers may use neutral "candidate" naming internally for plan classification, but they must not create pending memory cards or UI review queues.
- Extract pure helpers before changing orchestration code.
- Move tests with behavior, not after behavior.
- New Plaid or Stripe work should start in focused service files and integrate through existing facades only after the service has tests.

## Oversized File Exceptions

Generated files are exempt from the 500-line source limit. Existing oversized hand-written files should not grow further before they are split.

| File | Current status |
| --- | --- |
| `apps/mobile/lib/rex/chat/data/chat_models.freezed.dart` | Generated; exempt. |
| `apps/mobile/lib/app/ui_dependencies.dart` | Existing app bootstrap aggregate; split when the next dependency group changes. |
| `services/rex-api/app/services/entity_service.py` | Existing structured-memory facade; split entity CRUD/lookup before adding behavior. |
| `services/rex-api/app/services/plan_service.py` | Existing structured-plan facade; split plan, milestone, and commitment paths before adding behavior. |
| `apps/mobile/lib/rex/chat/presentation/pages/chat_page.dart` | Existing chat UI shell; next cleanup should extract composer and scroll orchestration. |

## Known Follow-Up Areas

- `prompt_service.py` and `rex_brain_context.py` remain backend cleanup targets.
- Budget, accountability, transaction, dashboard, and chat mobile files still exceed the preferred file-size limit.
- Broad backend exception handlers need a circuit-breaker ledger so intentional degraded behavior is separate from hidden bugs.
- Voice long-form input still needs final device validation.

## Plaid Integration Fit

Plaid transaction ingestion should not go into `chat_service.py`, direct memory services, dashboard widgets, or CSV import files. Prefer focused services for link-token exchange, account sync, transaction fetch, dedupe, and persistence. Rex should consume summarized financial context through the existing financial read-model and prompt/context path.

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
