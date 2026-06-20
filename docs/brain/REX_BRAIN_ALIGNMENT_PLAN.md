# REX_BRAIN_ALIGNMENT_PLAN.md

## 1. Vision Alignment Summary

Rex Brain is partially aligned with the MVP vision, but not fully. The active production path is mostly one shared chat/voice flow, memory truth is mostly protected, and backend confirmation rules are moving in the right direction. The biggest remaining gap is old chat recall: the current retrieval layer has become too complex, patched, and difficult to reason about. To reach the official vision, Rex Brain must return to a small, inspectable MVP flow: simple intent check, minimal context fetch, deterministic backend actions, short prompt to Grok, and light truth enforcement. Old chat recall must reliably search all user chats, clearly label results as chat history, and either return real context or honestly say nothing was found.

## 2. Non-Negotiable Alignment Principles

- Rex Brain must stay as small as possible.
- Chat and voice must use one production Rex Brain flow.
- Grok provides intelligence; Clarity provides data truth.
- Saved memory and chat history must stay separate.
- Only explicit backend-confirmed saves become durable categorized memory.
- Chat history must never be silently or automatically saved as memory.
- The Knows page must only show saved categorized memory.
- Old chat recall must search all chats for the current user, including old conversations and the current conversation.
- Old chat search must use simple keyword search first.
- Search must be strictly user-scoped.
- Rex must never claim a durable action happened unless the backend confirms it.
- Rex must report unavailable, degraded, or failed context sources honestly.
- Rex must not say search found nothing when search failed or was not checked.
- Rex must never invent limitations such as "I only search this chat" when full chat search is available.
- Prompts must stay short, labeled, and relevant.
- Truth enforcement must remain a small safety net, not a second brain.
- Future Hybrid Chat Search must strengthen the same Rex Brain flow, not create another assistant or memory system.

## 3. Alignment Phases

### Phase 1: Freeze The Single Production Brain

**Goal**

There is one clearly documented production Rex Brain path for chat and voice. Advanced or experimental brain code is either removed from the production surface or clearly deprecated so it cannot be mistaken for active MVP behavior.

**Specific rules from the docs this phase enforces**

- Use one production brain for chat and voice.
- Advanced routing must not create a second production brain.
- Keep Rex Brain small and easy to debug.

**Files to change / clean**

- `services/rex-api/app/services/chat_service.py`
- `services/rex-api/app/services/simple_rex_brain.py`
- Experimental `rex_brain_*` services
- Brain readiness docs/tests

**Exact changes needed**

- Confirm `ChatService` + `SimpleRexBrain` is the only production path.
- Remove production imports of unused advanced planning, contract, or routing modules.
- Mark remaining advanced `rex_brain_*` files as deprecated/experimental, or move them out of the production-facing service path.
- Ensure voice routes call the same chat service path as typed chat.
- Update tests/readiness output to describe the current path as "Simple Rex Brain," not disabled or base-only.

**Success verification steps**

- Run `rg "safe_plan_chat_turn|apply_chat_contract|build_prompt_messages_for_rex_brain" services/rex-api/app`.
- Confirm advanced brain calls are not active in production chat/voice flow.
- Manually test typed chat and voice input in the same conversation.
- Confirm both paths can recall saved memory and use old chat search through the same backend flow.

### Phase 2: Simplify Recall Into One Inspectable Service

**Goal**

Old chat recall becomes reliable, boring, and easy to debug. When the user asks about the past, Rex always performs saved memory lookup plus full user-scoped chat search and returns a clear status.

**Specific rules from the docs this phase enforces**

- Search saved memory and old chats when the user asks about past information.
- Search all user chats, including current and old conversations.
- Use simple keyword search first.
- Return conversation-level context, not isolated one-line snippets.
- Report degraded or unavailable search honestly.
- Avoid topic-specific patches and clever conditionals.

**Files to change / clean**

- `services/rex-api/app/services/chat_context_service.py`
- `services/rex-api/app/services/conversation_repository.py`
- `services/rex-api/app/services/chat_search_ranking.py`
- `services/rex-api/tests/test_chat_context_service.py`

**Exact changes needed**

- Create one recall path inside context fetching: `recall_request -> saved memory lookup + chat search`.
- Replace scattered recall conditionals with one clear predicate for past/history/remember/search-chat questions.
- Use generic keyword extraction from the user message.
- Keep only reusable aliases for broad categories: family, games, money, work, places, goals, preferences, events.
- Remove hardcoded topic patches that only exist for specific manual examples.
- Always include source status: found results, searched nothing, degraded/unavailable.
- When a match is found, load useful conversation-level context with the 500-message window.
- Keep prompt output capped to the best relevant matches.
- Success metric: Rex must pass all recall tests with zero hallucinated search limitations.

**Success verification steps**

- Add tests for arbitrary recall:
  - "What do you know about my mom?"
  - "Search chats about Legacy of Kain."
  - "Did I mention sending money?"
  - "What PC game did I say I was buying?"
  - "Did I mention immigration?"
  - "Search chats about payroll."
- Add tests proving chat search results do not become memory.
- Add tests proving search is user-scoped.
- Manual test each example in a fresh chat and an older chat.
- Confirm Rex either uses real chat context or says: "I searched my saved memory and old chats but couldn't find anything about that."

### Phase 3: Rebuild Prompt Context Around Labels And Status

**Goal**

Grok receives only the context needed for the current turn, clearly labeled as saved memory, chat history, financial data, or recent conversation.

**Specific rules from the docs this phase enforces**

- Keep prompts short and relevant.
- Chat search results must be labeled as chat history, not saved memory.
- Do not load broad memory or long chat history by default.
- A failed source is not proof that the user never said something.

**Files to change / clean**

- Prompt context builders
- Structured context formatters
- Prompt constants
- Prompt-related tests

**Exact changes needed**

- Keep the system prompt short.
- Include saved memory only when relevant.
- Include chat search results only for recall questions.
- Add a compact recall status block:
  - `saved_memory: found / empty / degraded`
  - `chat_search: found / empty / degraded`
  - `chat_result_count`
- Label chat excerpts as "Chat history, not saved memory."
- Remove repeated memory discipline text if the same rule is already present elsewhere.
- Keep financial context out unless the user asks a finance question or the turn clearly needs it.

**Success verification steps**

- Snapshot prompt assembly for normal chat, memory recall, chat recall, finance, and voice.
- Confirm normal chat does not include old chat search blocks.
- Confirm recall prompts include clear search status.
- Confirm chat history snippets are never labeled as memory.
- Confirm prompt size stays within the existing budget.

### Phase 4: Keep Memory Durable, Categorized, And Visible

**Goal**

Anything Rex saves is durable categorized memory, and only saved categorized memory appears in Knows.

**Specific rules from the docs this phase enforces**

- Only backend-confirmed saves become memory.
- Anything Rex saves is durable memory.
- There is no hidden or temporary save path.
- Saved memories must be categorized.
- Knows page must only show saved categorized memory.

**Files to change / clean**

- Memory services
- Memory intent/update services
- Knows page / mobile memory UI
- Memory tests

**Exact changes needed**

- Ensure every saved memory has a category such as People, Events, Places, Goals, Preferences, or Facts.
- Reject or clarify unclear saves, especially from voice transcripts.
- Confirm memory create/update/delete responses only use success language after backend confirmation.
- Confirm chat search results never appear in Knows unless explicitly saved.
- Ensure Knows UI groups memory by category using the saved memory category field.

**Success verification steps**

- Test saving a person fact, event, place, goal, preference, and generic fact.
- Test correction: "I live in Cambridge, not Somerville."
- Test deletion/update flows.
- Test unclear voice transcript does not create nonsense memory.
- Manual check Knows page categories and deletion/edit behavior.

### Phase 5: Keep Truth Enforcement Light But Strict

**Goal**

Truth enforcement blocks high-risk false claims without becoming another reasoning engine.

**Specific rules from the docs this phase enforces**

- Never claim a durable action happened unless backend confirms it.
- Do not say search found nothing when search failed.
- Do not invent saved memories, financial facts, or completed actions.
- Truth check must remain a small safety net.

**Files to change / clean**

- Action truth policy
- Chat service response post-processing
- Truth policy tests

**Exact changes needed**

- Keep blockers focused on durable action claims, failed/degraded search claims, memory save claims, fake financial facts, and fake search limitations.
- Keep truth enforcement compact, preferably under 100-150 lines for the main policy surface.
- Remove overly broad phrase patches that try to steer normal conversation.
- Add one canonical fallback for degraded recall.
- Add one canonical fallback for completed recall with no results.
- Prevent fake limitation claims such as "I only search this chat" when backend search is available.

**Success verification steps**

- Test failed memory search.
- Test failed old chat search.
- Test successful old chat search.
- Test no-result old chat search.
- Test unsupported action requests.
- Test memory save failure.
- Manual test Rex never claims fake search limitations.

### Phase 6: Voice And Chat Final Consistency

**Goal**

Voice is only another input/output mode for the same conversation and the same Rex Brain.

**Specific rules from the docs this phase enforces**

- Voice and chat use the same brain.
- Voice must not use a separate memory system, action system, or truth policy.
- Voice can be cautious when transcripts are unclear.

**Files to change / clean**

- Voice route/controller
- Chat input voice mode
- Voice response/TTS handling
- Voice-related tests

**Exact changes needed**

- Confirm voice messages are saved into the same conversation history.
- Confirm typed replies during voice mode use the same conversation.
- Confirm voice replies can be spoken while also appearing as normal chat messages.
- Keep voice-specific instructions limited to transcript caution and concise spoken response style.
- Ensure unclear transcripts ask for clarification before saving memory.

**Success verification steps**

- Manual voice test: ask recall question about mom.
- Manual voice test: ask recall question about games.
- Manual voice test: save a memory by voice.
- Manual voice test: unclear transcript does not save.
- Manual typed-after-voice test in the same conversation.

## 4. Simplification Reset Strategy

The reset should target the recall/context layer, not the entire Rex Brain. Keep the good parts: one `ChatService` production path, deterministic backend-confirmed memory actions, shared voice/chat backend flow, source status tracking, and truth enforcement for high-risk claims. Remove or reduce complexity that makes recall unpredictable: scattered recall conditionals, topic-specific patches, broad prompt instructions, phrase-heavy post-processing, and experimental code that looks production-ready. The new recall layer should be a single inspectable pipeline: detect recall request, extract simple keywords, search saved memory, search all user chats, load conversation-level context, return found/empty/degraded status, and send only labeled relevant context to Grok.

## 5. Final Verification & Launch Checklist

- One production Rex Brain flow is documented and verified.
- Chat and voice use the same backend brain path.
- Advanced brain files are removed from production imports or clearly deprecated.
- Saved memory requires explicit user intent and backend confirmation.
- Saved memory is categorized.
- Knows page only shows saved categorized memory.
- Chat history is never silently saved as memory.
- Old chat recall searches all current-user chats.
- Old chat recall includes current and older conversations.
- Recall results are labeled as chat history, not saved memory.
- Recall has clear found/empty/degraded status.
- Rex never says "I do not know" when search failed or was not checked.
- Rex never claims "I only search this chat" when full chat search is available.
- Rex passes recall tests with zero hallucinated search limitations.
- Rex never claims a memory/action/save/delete/update succeeded without backend confirmation.
- Financial answers use only Clarity/Plaid/Supabase/current-user context.
- Prompt snapshots are short and clearly labeled.
- Manual recall tests pass for mom, Legacy of Kain, PC game, sending money, payroll, immigration, places, goals, and preferences.
- Full relevant backend tests pass.
- Manual voice and typed chat tests pass in the same conversation.

## 6. Anti-Regression Rules

- Do not add a second production brain path.
- Do not add topic-specific recall patches for one manual test.
- Do not fix recall failures with prompt-only changes when retrieval is the issue.
- Do not let truth enforcement grow beyond a small safety layer.
- Do not load old chats unless the user asks for recall or the intent clearly requires it.
- Do not show chat search results on Knows unless the user explicitly saves them.
- Do not use success language without backend confirmation.
- Do not hide degraded memory, chat search, financial, or file context.
- Do not add new recall behavior without tests for found, empty, degraded, and multi-user isolation.
- Prefer one simple inspectable pipeline over many clever branches.
