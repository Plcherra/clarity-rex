# PROJECT_STRUCTURE.md

**Canon:** tech stack, repository layout, coding conventions, file-size policy, and production wiring for finance and the assistant.

Product vision: [`MASTER_PLAN.md`](MASTER_PLAN.md). Behavioral rules: [`CLARITY_RULES.md`](CLARITY_RULES.md).

## 1. Tech Stack

| Layer | Technology |
| --- | --- |
| Mobile | Flutter / Dart · Riverpod |
| Backend | Python / FastAPI (`services/rex-api`) |
| Database & Auth | Supabase / Postgres |
| Bank connections | Plaid (CSV import fallback) |
| Assistant LLM | Grok via backend |
| Voice | Mobile capture + backend STT/TTS (Deepgram, Google TTS) |

## 2. Repository Layout

```text
apps/mobile/          Flutter app
  lib/app/            Bootstrap, routing shell
  lib/core/           Supabase/config, shared models, Rex API client
  lib/features/       Financial features (dashboard, accounts, budgets, transactions, profile)
  lib/rex/            Assistant (chat, voice, memory, goals)
  lib/theme/          Design tokens and Material themes
  lib/widgets/        Reusable UI components

services/rex-api/     FastAPI backend — chat, voice, memory, Plaid sync, prompts
supabase/             Migrations, Edge Functions, auth templates
```

**Separation rule:**
- All financial features live under `apps/mobile/lib/features/`.
- All assistant code lives under `apps/mobile/lib/rex/`.
- They share data models from `apps/mobile/lib/core/`.
- Do not mix assistant code inside features or financial code inside `rex/`.

## 3. Feature-First Module Pattern

```text
feature/
  domain/          models, policies, business rules
  application/     workflows, controllers, use cases
  data/            repositories, API clients, mappers
  presentation/    screens, widgets, view models
```

Presentation depends on application/domain, never the reverse.

## 4. File Size and Split Policy

**STOP before editing any file over 400 lines.** Extract first, patch second.

| Scope | Target | Stop | Never exceed |
| --- | --- | --- | --- |
| All code | 150–300 lines | 400 lines | **500 lines** |
| Assistant context / recall / prompt modules | 150–250 lines | **400 lines** | **500 lines** |

**Before you edit:**
1. Check line count of the target file.
2. If **over 500**: do not add features — split the file first.
3. If **400–500**: extract new logic into a focused module; only tiny fixes in the oversized file.
4. If **under 400**: normal edits; stop before hitting 400.

**Split recipe:**
- One thin orchestrator (e.g. `handle_turn`, route handler) — ~80–120 lines.
- Focused modules by responsibility — parsing, queries, writes, formatting.
- Move tests with extracted code; keep public behavior unchanged.

**Known violators** (`services/rex-api/app/services/`) — re-audit when touched:

| File | Notes |
| --- | --- |
| `chat_turn_orchestrator.py` | support + short-circuit helpers extracted |
| `chat_recall_search.py` | runners extracted |
| `memory_correction_service.py` | apply module extracted |
| `recall_intent_helper.py` | constants, detection, query modules |

`chat_context_service.py` was split and is under the limit — do not re-grow it. Same limits apply under `apps/mobile/lib/`.

## 5. Coding Conventions

- Use clear, specific domain names. Avoid vague names like `utils`, `helper`, `manager`.
- Keep business logic out of UI widgets.
- Add tests for important logic and workflows.
- Do not silently swallow user-critical errors.
- Plaid tokens must remain backend-owned.
- All user data must be properly scoped to the authenticated user.

## 6. Assistant Production Path

One production pipeline for chat and voice. Grok does reasoning; the backend loads context, proposes/applies durable writes, and runs a light truth check.

```text
User message (chat or voice)
  → ChatService
  → ChatTurnOrchestrator
      → pending confirm/reject?     → DurableWriteApplier.apply / reject
      → save intent?                → DurableWriteService.propose → write_proposals
      → thread proposal/confirm?    → OpenThreadService (write)
      → substantive turn?           → load active open threads → prompt (labeled)
      → recall intent?              → ChatRecallService (read-only excerpts)
      → inventory intent?           → SavedKnowledgeOverviewService → prompt
      → else                        → SimpleRexBrain + Grok
      → light truth check           → response
  → Rex response
```

**Key backend files:**

| Role | File |
| --- | --- |
| Main orchestrator | `services/rex-api/app/services/chat_service.py` |
| Turn routing | `services/rex-api/app/services/chat_turn_orchestrator.py` |
| Production brain surface | `services/rex-api/app/services/simple_rex_brain.py` |
| Intent classification | `services/rex-api/app/services/rex_intent_router.py` |
| Prompt context facade | `services/rex-api/app/services/chat_context_service.py` |
| Prompt assembly | `services/rex-api/app/services/prompt_service.py` |
| Truth guard | `services/rex-api/app/services/action_truth_policy.py` |

**Key mobile files:**

| Role | File |
| --- | --- |
| Chat | `apps/mobile/lib/rex/chat/application/chat_controller.dart` |
| Voice | `apps/mobile/lib/rex/voice/application/voice_call_controller*.dart` |
| Knows | `apps/mobile/lib/rex/memory/application/memory_controller.dart` |
| HTTP client | `apps/mobile/lib/core/rex/rex_api_client.dart` |
| Confirm cards | `apps/mobile/lib/rex/chat/presentation/widgets/clarity_action_cards_strip.dart` |

**Non-production:** `services/rex-api/app/services/rex_brain*.py` are experiments. Do not debug production assistant behavior there unless explicitly working on experiments.

## 7. Memory and Recall Wiring

### Write-path invariants

1. One production pipeline (`SimpleRexBrain` + `ChatTurnOrchestrator`) for chat and voice.
2. Durable writes: `DurableWriteProposal` → pending action → confirm card → frozen `apply_snapshot`.
3. Mobile receives `write_proposals` only (no hidden discipline metadata).
4. After confirm, item is visible in Knows or Goals without manual refresh.
5. Open Threads require explicit consent — no silent create.

**Requires confirm card (chat/voice):** flat memory, plans/goals, entity events, deletes.

**Manual UI:** Knows / Goals REST CRUD — user fills form and taps Save.

**Mobile confirm flow:** `write_proposals` → `ClarityActionCardsStrip` → `write_confirmation` → refresh `memoryProvider` + `accountabilityProvider`.

### Write lifecycle

```text
UserIntent → MemoryDisciplineService.decide() (where wired)
          → BackendConfirmedWrite (create/update via service or repository)
          → Optional person materialization (save path only, not read path)
          → memory_changes / Knows refresh
```

- `MemoryDisciplineService` runs before structured creates and flat creates (`POST /memory`, chat saves).
- Duplicate detection merges or updates existing records instead of silently creating duplicates.
- UI success is allowed only after the backend returns a confirmed record id.
- Person materialization runs after confirmed person-category flat saves — **not** on Knows read/list paths.

### Production paths

| Area | Backend | Mobile |
| --- | --- | --- |
| Chat turn | `ChatService`, `ChatTurnOrchestrator`, `SimpleRexBrain` | `ChatController`, `ChatApi` |
| Saved flat memory | `/memory`, `long_term_memory_repository.py`, `memory_write_service.py` | `MemoryApi`, `MemoryPage` |
| Structured memory | `/entities`, `/rules`, `/plans` | `memory_structured_api.dart`, Knows tiles |
| Person/entity cards | `entity_service.py` | person memory models, saved memory group list |
| Goals | `/plans`, `/accountability/overview` | `AccountabilityPage`, Goals section |
| Open Threads | `open_thread_service.py`, `/open-threads` | Goals tab Open Threads section |
| Old chat search | `conversation_repository.py`, `chat_search_*`, `chat_recall_*` | Chats tab search, recall context |
| Saved-knowledge overview | `SavedKnowledgeOverviewService`, `/saved-knowledge/overview` | Knows tab |
| Prompt labels | `prompt_memory_context.py`, `prompt_open_threads_context.py`, `prompt_structured_context.py` | N/A (backend-owned) |
| Truth enforcement | `chat_response_truth.py`, `action_truth_policy.py` | Chat UI displays backend response state |

### Recall modules

| Role | File |
| --- | --- |
| Recall intent | `recall_intent_helper.py` |
| Chat search fetch | `chat_recall_service.py` |
| Chat search ranking | `chat_search_ranking.py` |
| User-scoped storage | `conversation_repository.py` |

Prompt modules label old chat hits as `Chat history, not saved memory`. `action_truth_policy.py` handles degraded, filtered, partial, and empty recall fallbacks.

### Knows manual create

- Flat fact/preference via `POST /memory`
- Person, rule, plan via structured create routes
- Open Threads are **not** created through Knows — use `/open-threads` or consent flow in Goals context

### Duplicate suppression

When a flat long-term memory is fully covered by a structured person card, archive the flat memory instead of showing a second active Knows item.

### Memory corrections

`/memory/corrections` remains for diagnostics. Knows does not show a Corrections tab in MVP.

### Legacy

- **Commitments fully removed** (July 2026). The `commitments` table, routes, and assistant write paths are deleted. Companion continuity uses **Open Threads** only; plan-linked small steps use **milestones**.
- Early `memory_candidates` / `memory_confirmations` tables are archived. Durable memory uses discipline + backend-confirmed creates only.
- Disabled bypass paths: `GoalCommandReclassifier` direct memory→goal writes, separate `save_plan` pending, auto merge unless `merge_disclosed_to` is set, auto person materialization on generic LTM REST create.

### Ops scripts

Run from `services/rex-api` after env is loaded:

| Script | Purpose |
| --- | --- |
| `scripts/backfill_structured_memory.py` | Batch promotion of flat memories into structured entities/plans/rules |
| `scripts/apply_memory_corrections.py` | Classify/apply user corrections and dry-run duplicate audits |
| `scripts/cleanup_user_memory_duplicates.py` | Per-user Knows duplicate cleanup |

`SupabaseMemoryService` in `memory_service.py` is the production Supabase facade for conversations and memory.

## 8. Open Threads Wiring

Goals tab overview returns `{ plans, open_threads }`.

**Backend modules:**
- `open_thread_service.py`, `open_thread_repository.py`, `open_thread_turn_service.py`
- `open_thread_context_loader.py`, `open_thread_eligibility.py`
- `prompt_open_threads_context.py` — capped, labeled prompt section
- `GET/PATCH/POST /open-threads` (user-scoped)

**Flow:**

```text
ChatTurnOrchestrator
  → thread proposal / confirm? → OpenThreadService (write)
  → fetch active threads (read) → prompt block
  → recall? → ChatRecallService (unchanged)
  → saved memory? → existing paths (unchanged)
  → Grok
```

Open Threads are not included in `SavedKnowledgeOverviewService` / Knows.

## 9. Finance Wiring

### Canonical Supabase tables

| Data | Table |
| --- | --- |
| Profiles | `profiles` |
| Accounts | `accounts` |
| Plaid account metadata | `plaid_accounts` |
| Plaid item/token state | Backend-owned Plaid tables |
| Transactions | `transactions` |
| Categories | `categories` |
| Budgets | `budgets` |
| Merchant learning | `merchant_category_rules` |
| CSV import batches | `account_statement_imports` |
| Financial audit | `financial_audit_events` |

### Mobile read path

`apps/mobile/lib/features/finance/application/financial_read_model_service.dart` loads accounts, transactions, budgets, categories, merchant rules, and import batches.

Same read model powers Dashboard, Account detail, Budgets, Transaction review, and assistant financial context.

Supabase access: `apps/mobile/lib/core/supabase/supabase_repository.dart`.

### Mobile write path

Native finance UI writes directly to Supabase through feature services: `AccountService`, `TransactionService`, `CategoryService`, `BudgetService`, `MerchantCategoryRuleService`, `AccountStatementImportService`.

Writes must stay user-scoped through Supabase Auth and RLS. Validate before writing; show failure on reject; refresh read model after success; record audit events where supported.

### Assistant financial context

Mobile builds a summary via `apps/mobile/lib/rex/data/financial_context_service.dart` and sends it only on clearly financial turns.

Backend: `chat_financial_guard.py` gates financial context to finance intent. Prompt formatter: `prompt_financial_context.py`.

The assistant does not independently fetch finance records today.

### Assistant financial action writes

Confirmed actions route through `/clarity/actions` → `ClarityControlService` → Supabase. This is a second write path to the same finance tables — same validation, audit, refresh, and confirmation rules as native UI writes.

Complete only when: user confirms, backend returns applied result, mobile marks applied, mobile refreshes via `notifyDataChanged()`, assistant does not claim success before backend result exists.

### Plaid path

Backend-owned: mobile requests link tokens through backend → Plaid Link → public token → backend exchange → sync accounts/transactions → mobile reads Supabase records. Mobile reads Plaid item status from backend for recovery states. Plaid tokens and secrets must never be stored in mobile code.

### CSV path

Account-scoped CSV import from Accounts or account detail. Edge Function `categorize-transactions` for AI categorization. `UploadScreen` was removed.

## 10. Voice Wiring

Voice uses the same `ChatService` / `ChatTurnOrchestrator` path as chat.

**Production path:**

```text
Mobile inline voice panel
  → WebSocket `/voice/stream`
  → Deepgram streaming STT
  → ChatService / SimpleRexBrain
  → Google TTS
  → Mobile streaming audio playback
```

**Fallback** (streaming disabled or WebSocket unavailable):

```text
Mobile captured utterance
  → REST `/voice/turn`
  → Deepgram STT → ChatService → Google TTS → playback
```

**Runtime flags:**

| Flag | MVP default | Meaning |
| --- | --- | --- |
| `REX_CLOUD_VOICE_ENABLED` | `true` | Backend voice fallback |
| `REX_STREAMING_VOICE_ENABLED` | `true` | WebSocket streaming voice |
| `REX_EXPERIMENTAL_NATIVE_IOS_VOICE_ENABLED` | `false` | Native bridge experiments only |
| `REX_NATIVE_IOS_VOICE_ENABLED` | ignored | Legacy; do not use for release |

Native iOS voice bridge is experimental and must not become a second assistant pipeline.

**Usage tracking:** backend records STT/TTS/LLM turns and session duration. Profile voice usage reads `user_voice_summaries` from Supabase; backend also exposes `/usage/me`.

## 11. Product Routes (current)

- CSV import: account-scoped flow from Accounts or account detail (not standalone upload screen).
- Transaction review: production surface from Dashboard app bar (global and account-scoped).
- Knows, Goals (plans + Open Threads), Chats, Voice: under `apps/mobile/lib/rex/`.

## 12. Where to Look First

| Question | Start here |
| --- | --- |
| What is Clarity? | `docs/MASTER_PLAN.md` |
| What must the assistant do? | `docs/CLARITY_RULES.md` |
| Where is the code? | This file |
| Finance read model | `financial_read_model_service.dart` |
| Chat turn | `chat_service.py`, `chat_turn_orchestrator.py` |
| Memory writes | `memory_write_service.py`, `DurableWriteService` |
| Open Threads | `open_thread_service.py`, `/open-threads` |
| Plaid sync | `services/rex-api` Plaid routes and sync services |

## 13. Documentation Policy

**Canon:** only three documents in `docs/` root — `MASTER_PLAN.md`, `CLARITY_RULES.md`, `PROJECT_STRUCTURE.md`.

- Do not add new planning, architecture, or feature docs under `docs/`.
- Archived non-canon material may live under `docs/archive/` only.
- Historical execution trackers live under `docs/archive/` only — not canon.
- CI runs `scripts/verify_docs_canon.sh` to block new non-canon files under `docs/`.
