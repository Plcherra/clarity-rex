# Clarity Project Map

This is the short map for the current production architecture. It is meant to
answer: "Where should I look first?" It is not a replacement for the detailed
brain docs.

## Product Shape

Clarity is one Flutter app backed by Supabase and a FastAPI Rex API.

- Mobile app: `apps/mobile`
- Rex API backend: `services/rex-api`
- Financial source of truth: Supabase/Plaid-backed finance records
- Assistant source of truth: Rex API memory, chat history, and prompt context

## Production Rex Brain

The production brain is the simple MVP path:

```text
User message
 -> ChatService
 -> SimpleRexBrain + RexIntentRouter
 -> ChatTurnContextService
 -> ChatContextService facade
 -> optional MemoryTurnService / GoalCommandService direct action
 -> PromptService
 -> Grok
 -> action_truth_policy
 -> Rex response
```

Key files:

- `services/rex-api/app/services/chat_service.py` - main production
  orchestrator for chat and voice turns.
- `services/rex-api/app/services/simple_rex_brain.py` - small production
  brain surface.
- `services/rex-api/app/services/rex_intent_router.py` - lightweight intent
  classification and context-load flags.
- `services/rex-api/app/services/chat_context_service.py` - compatibility
  facade for prompt context.
- `services/rex-api/app/services/prompt_service.py` - prompt assembly.
- `services/rex-api/app/services/action_truth_policy.py` - final truth guard
  against fake actions and bad recall claims.

Voice uses the same `ChatService` path. There should not be a separate voice
brain.

## Memory Layers

Saved memory is durable only after backend confirmation.

- Flat memory: `long_term_memory`, exposed by
  `long_term_memory_repository.py`.
- Structured memory: entities, events, rules, plans, commitments, exposed by
  `structured_memory_repository.py`.
- Person cards: materialized from high-confidence flat facts by
  `person_memory_materializer.py`.
- Knows UI: `apps/mobile/lib/rex/memory/...`.

Entity/Person memory is the main active Knows model when it fully covers a flat
fact. Flat memory remains traceable source/history, not a competing active row.
Chat history is never saved memory unless the user explicitly saves it.

## Recall Layers

Recall means Rex searches saved memory and old chats when the user asks about
past information.

- Trigger policy: `recall_intent_helper.py`.
- Intent routing: `rex_intent_router.py` delegates recall-shaped decisions to
  the recall helper.
- Chat search fetch: `chat_recall_service.py`.
- Chat search ranking: `chat_search_ranking.py`.
- User-scoped chat storage/search: `conversation_repository.py`.
- Prompt labeling: `prompt_memory_context.py` and
  `prompt_structured_context.py`.

Old chat hits must be labeled as chat history, not saved memory.

## Mobile State

Rex mobile state is Riverpod-based:

- Chat: `apps/mobile/lib/rex/chat/application/chat_controller.dart`
- Voice: `apps/mobile/lib/rex/voice/application/voice_call_controller*.dart`
- Knows: `apps/mobile/lib/rex/memory/application/memory_controller.dart`
- Rex HTTP client: `apps/mobile/lib/core/rex/rex_api_client.dart`

After backend-confirmed memory changes, chat refreshes the Knows overview so the
mobile cache does not show stale active records.

## Product Routes

The current user-facing screen and route wiring is tracked in
`docs/PROJECT_ROUTE_MAP.md`.

Important wiring decisions:

- CSV import uses the account-scoped fallback flow from Accounts or account
  detail. The old standalone upload screen is not a production route.
- Transaction review is a production surface reachable from the Dashboard app
  bar for both global and account-scoped dashboards.

## Finance Truth

Financial features live under `apps/mobile/lib/features`.

- Canonical mobile finance read model:
  `apps/mobile/lib/features/finance/application/financial_read_model_service.dart`
- Supabase finance access:
  `apps/mobile/lib/core/supabase/supabase_repository.dart`
- Rex financial context builder:
  `apps/mobile/lib/rex/data/financial_context_service.dart`
- Backend finance prompt formatter:
  `services/rex-api/app/services/prompt_financial_context.py`

Financial context should only be sent to Rex on clearly financial turns. Rex
must not invent balances, budgets, merchants, transactions, or account names.

## Non-Production Brain Code

Do not debug production Rex behavior in the experimental brain stack unless a
task explicitly says to work on experimental routing.

Non-production files include:

- `services/rex-api/app/services/rex_brain*.py`
- `services/rex-api/app/services/rex_model_router.py`

The production path is `ChatService` plus `SimpleRexBrain`. Experimental files
may have tests for historical contracts, but they are not the launch brain.

## Detailed References

- `docs/brain/REX_BRAIN_RULES.md`
- `docs/brain/REX_BRAIN_ARCHITECTURE.md`
- `docs/brain/REX_BRAIN_MEMORY_FIXES.md`
- `docs/PROJECT_ROUTE_MAP.md`
- `docs/master-plan.md`
