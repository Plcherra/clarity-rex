# P3 — Rex Chat, Knows, and Goals on Web

**Previous:** [P2_ADAPTIVE_SHELL.md](./P2_ADAPTIVE_SHELL.md) (exit criteria met)  
**Next:** [P4_PLAID_WEB.md](./P4_PLAID_WEB.md) or [P5_VOICE_WEB.md](./P5_VOICE_WEB.md)

**Status:** **In progress** (2026-06-30)

## Objective

Assistant parity for text-based Rex workflows on web.

## Prerequisites

- P1 complete (auth, rex-api CORS, no boot crashes)
- P2 complete (assistant tab usable on desktop width)

## Tasks

### 1. Rex chat streaming

Verify `chat_api.dart` HTTP streaming on Chrome.

Fix web blockers:

- Remove or conditionalize `dart:io` in chat attachment path (`chat_input_bar.dart`, `chat_message_bubble.dart`) — **done** via `ChatAttachmentImage` + conditional local file helper
- File/image attachments: work via `file_picker` / `cross_file` on web, or gate with clear copy — **web uses file picker directly**; mobile keeps gallery/camera sheet
- Voice mic shows honest “coming soon on web” copy until P5 — **done**

### 2. Knows / memory

Verify on web:

- `memory_page.dart` — list, search, filters
- CRUD via rex-api (`memory_api.dart`, structured memory)
- Saved memory truth labeling unchanged (no web-only recall patches)

### 3. Goals tab

Verify in `assistant_screen.dart` Goals tab:

- Create goal / commitment
- Complete / archive
- Empty state and Rex prompts

### 4. Conversations tab

Verify chat history list and reopen conversation on web.

### 5. Voice UI on web (stub only)

Voice button may show "Voice coming soon on web" until P5 — or hide behind `AppCapabilities.supportsStreamingVoice`. Do not half-ship broken voice in P3.

## Exit criteria

- [ ] Send chat message → streamed Rex reply on Chrome
- [ ] Search Knows, view and edit saved memory
- [ ] Create and complete a goal
- [ ] Chat attachments work OR disabled with honest user-visible message
- [ ] No Rex answers treat chat search as saved memory (same truth policy as mobile)

## Tests

- Run chat + memory backend tests (`services/rex-api/tests/`)
- Mobile: memory page tests, chat-related tests
- Manual: recall question in chat uses same pipeline as mobile

## Files likely touched

- `apps/mobile/lib/rex/chat/data/chat_api.dart`
- `apps/mobile/lib/rex/chat/presentation/widgets/chat_input_bar.dart`
- `apps/mobile/lib/rex/memory/presentation/pages/memory_page.dart`
- `apps/mobile/lib/rex/presentation/assistant_screen.dart`

## Out of scope (defer)

- Plaid (P4)
- Streaming voice (P5)
- PWA deploy (P6)
