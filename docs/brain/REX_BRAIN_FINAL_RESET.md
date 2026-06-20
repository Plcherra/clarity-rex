# REX_BRAIN_FINAL_RESET.md

## 1. Purpose

This is the active pre-launch Rex Brain cleanup plan.

It only includes work that should be completed before launch on the 25th. Larger memory, Knows, migration, hybrid search, and advanced brain work belongs in `docs/brain/REX_BRAIN_POST_LAUNCH.md`.

The goal is to make the current MVP safer and easier to debug without changing the product shape or creating another brain.

## 2. Current Launch Reality

Rex Brain is mostly on the right production path:

- Chat and voice use the same `ChatService` flow.
- `SimpleRexBrain` is the production brain surface.
- Durable memory actions require backend confirmation.
- Chat search results are labeled separately from saved memory.
- Recall source status exists and is included in prompts.

The remaining launch risks are practical:

- Financial context is attached too broadly and can pollute non-finance turns.
- Financial prompt budget is much larger than memory and recall context.
- `chat_context_service.py` is still a god file.
- Recall behavior works for tested examples but is hard to trace.
- Truth policy still patches some recall failures after generation.
- Experimental `rex_brain_*` files and old docs can confuse the production path.

## 3. Pre-Launch Principles

- Fix launch risks before architectural ambitions.
- Keep one production Rex Brain for chat and voice.
- Do not create a second memory system, recall system, prompt contract, or router.
- Preserve current working recall behavior while simplifying the code around it.
- Keep saved memory, chat history, and financial context clearly labeled.
- Backend confirmation is required before Rex claims a durable action succeeded.

## 4. Pre-Launch Phases

### Phase 1: Gate Financial Context

**Goal**

Prevent financial data from being sent or prompted on casual, memory, and old-chat recall turns.

**Key files**

- `apps/mobile/lib/rex/chat/application/chat_controller.dart`
- `apps/mobile/lib/rex/voice/application/voice_call_controller_streaming.dart`
- `services/rex-api/app/services/rex_intent_router.py`
- `services/rex-api/app/services/chat_service.py`
- `services/rex-api/app/services/simple_rex_brain.py`
- `services/rex-api/app/services/prompt_service.py`
- `services/rex-api/app/services/prompt_financial_context.py`

**Exact changes**

- Add a lightweight client-side finance intent check before building financial context.
- Send financial context only for finance, budget, account, spending, transaction, income, cash-flow, Plaid, or money-management turns.
- Do not send an unavailable financial summary for every non-finance turn.
- Backend must ignore supplied financial context unless the classified intent allows financial context.
- Update tests so memory recall with an attached financial payload does not include financial context.

**Success criteria**

- "What do you know about my mom?" sends and prompts no financial context.
- "Search old chats about Legacy of Kain" sends and prompts no financial context.
- "Hey Rex" sends and prompts no financial context.
- Finance questions still get the same Clarity/Plaid/Supabase-backed data.
- Rex says when financial data is unavailable only on finance-relevant turns.

### Phase 2: Trim Prompt Budgets

**Goal**

Keep prompts short and prevent financial context from crowding out memory or recall context.

**Key files**

- `services/rex-api/app/services/prompt_constants.py`
- `services/rex-api/app/services/prompt_service.py`
- `services/rex-api/app/services/prompt_financial_context.py`
- `services/rex-api/app/services/prompt_memory_context.py`
- `services/rex-api/tests/test_prompt_service.py`
- `services/rex-api/tests/test_prompt_context_budgets.py`

**Exact changes**

- Reduce the financial context character budget to a launch-safe cap.
- Keep saved memory and chat search results capped and clearly labeled.
- Ensure normal chat uses only the base Rex prompt.
- Ensure recall prompts include only relevant saved memory and chat search results.
- Add or update prompt snapshot/budget tests for finance, recall, and casual turns.

**Success criteria**

- Casual prompts remain tiny.
- Recall prompts are free of unrelated finance context.
- Finance prompts include financial context only when finance intent allows it.
- Prompt tests prove financial context cannot dominate memory recall turns.

### Phase 3: Split The Riskiest Context God-File Pieces

**Goal**

Make context fetching easier to inspect without changing behavior.

**Key files**

- `services/rex-api/app/services/chat_context_service.py`
- `services/rex-api/app/services/chat_search_ranking.py`
- `services/rex-api/tests/test_chat_context_service.py`
- `services/rex-api/tests/test_chat_search_ranking.py`
- `services/rex-api/tests/test_conversation_repository_search.py`

**Exact changes**

- Keep `ChatContextService` as the orchestration facade.
- Extract recall detection/query shaping into a small helper module.
- Extract chat recall retrieval/excerpt assembly into one focused service.
- Extract memory source status assembly into one small helper.
- Keep current tests passing while moving code.
- Do not introduce new routing, models, or prompt contracts.

**Success criteria**

- The production message path is unchanged.
- Recall, memory status, and chat search tests still pass.
- `chat_context_service.py` is smaller and easier to scan.
- A developer can trace recall context fetching without reading the whole file.

### Phase 4: Stabilize Recall Status And Labels

**Goal**

Make the existing recall behavior reliable enough for launch without redesigning retrieval.

**Key files**

- `services/rex-api/app/services/chat_context_service.py`
- Extracted recall helper/service files from Phase 3
- `services/rex-api/app/services/prompt_memory_context.py`
- `services/rex-api/app/services/prompt_structured_context.py`
- `services/rex-api/app/services/action_truth_policy.py`
- `services/rex-api/tests/test_chat_context_service.py`
- `services/rex-api/tests/test_action_truth_policy.py`

**Exact changes**

- Keep one clear recall predicate for past/history/remember/search-chat questions.
- Preserve broad keyword search and reusable aliases.
- Avoid new one-off topic patches.
- Keep source status explicit: found, empty, degraded.
- Prompt chat matches as "Chat history, not saved memory."
- Keep post-generation truth checks as a safety net only.

**Success criteria**

- Recall works from a fresh chat and an existing chat.
- Empty answers only happen after successful saved-memory and chat search.
- Degraded search is reported as degraded, not as "I know nothing."
- Tests continue covering mom, games, Legacy of Kain, money, immigration, payroll, and arbitrary topics.

### Phase 5: Clarify Docs And Experimental Brain Code

**Goal**

Make it obvious what is production for launch.

**Key files**

- `docs/brain/REX_BRAIN_RULES.md`
- `docs/brain/REX_BRAIN_ARCHITECTURE.md`
- `docs/brain/REX_BRAIN_HYBRID_CHAT_SEARCH.md`
- `docs/brain/REX_BRAIN_ALIGNMENT_PLAN.md`
- `docs/brain/REX_BRAIN_POST_LAUNCH.md`
- `services/rex-api/app/services/rex_brain_*`

**Exact changes**

- Keep this file as the active pre-launch cleanup plan.
- Keep post-launch work in `REX_BRAIN_POST_LAUNCH.md`.
- Mark completed alignment docs as historical or launch-complete.
- Ensure experimental `rex_brain_*` files are clearly non-production.
- Do not add another large planning document.

**Success criteria**

- A developer can identify the production Rex Brain path quickly.
- There is one active pre-launch plan.
- Post-launch work is not mixed into launch-critical tasks.
- Brain docs are concise, current, and non-overlapping.

## 5. Pre-Launch Verification Checklist

- Chat and voice still use one production `ChatService` path.
- `SimpleRexBrain` remains the production brain surface.
- Direct memory saves, updates, and deletes require backend confirmation.
- Chat history is searched for recall questions and labeled as chat history.
- Chat history is never treated as saved memory unless explicitly saved.
- Financial context is only sent and included for finance-relevant turns.
- Recall prompts are short, labeled, and free of unrelated finance context.
- "What do you know about my mom?" checks saved memory and old chats without finance context.
- "Search old chats" searches all current-user conversations, not only the visible thread.
- Empty recall answers only happen after successful saved-memory and chat search.
- Degraded memory or chat search is reported honestly.
- Prompt budgets are balanced for launch.
- `chat_context_service.py` no longer contains the riskiest recall/status tangles.
- Experimental brain code is clearly non-production.
- Larger entity-memory and hybrid-search work is tracked in `REX_BRAIN_POST_LAUNCH.md`.
