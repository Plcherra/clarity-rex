# MVP Fix Plan

This plan is organized by launch priority groups. Work one full group at a time, starting with Group 1.

Group 1 is complete. Rex now searches old chats as conversation-level history instead of isolated keyword hits. The simple MVP Rex Brain follows the strict "Saved = Memory" model: saved records are durable categorized memory, chat search results remain chat history, and Rex must not blur the two.

## Group 1: Core Trust & Truth Issues (Highest Priority)

Status:
Complete.

Group 1 Completed Summary:

- Rex Brain uses one simple MVP production flow for chat and voice.
- Durable memory writes require backend confirmation.
- Saved memory is categorized and visible through the Knows page categories.
- Chat search results are separate chat history, not memory or pseudo-memory.
- Hidden chat-to-memory auto-saving is disabled.
- Rex reports degraded memory/chat search instead of pretending nothing exists.
- Unsupported or unconfirmed actions cannot be presented as completed.
- Chats tab search is available for user-visible conversation lookup.
- Old-chat recall now uses generic expanded search terms and conversation-level excerpts so Rex can find related details from older chats without one-off mom/birthday behavior.
- User-scoped service tests now cover message search, conversation search, and conversation message context fetches.

Current search boundary:
Group 1 completed the MVP keyword-search baseline. Rex can search old chats more reliably, but this is not full Hybrid Chat Search yet. The next search work is tracked in Group 2 for launch hardening and Group 3 for semantic/hybrid retrieval.

High-Level Overview of Rex Brain and Memory System (MVP Scope):
Rex's production brain for launch is one simple assistant flow.

```text
User message
  -> Simple intent check
  -> Minimal context fetch
  -> Optional direct backend action
  -> Short prompt to Grok
  -> Light truth check
  -> Rex response
```

Grok provides most of the intelligence. Clarity provides the data truth.

**MVP Launch Rule (non-negotiable for fast launch):**
There is one production Rex Brain for MVP. It is active, simple, and shared by chat and voice.

Advanced routing, model selection, deeper planning, layer-specific prompt contracts, and experimental brain code may remain in the tree, but they must not define MVP behavior or create a second production brain.

Group 1 launch trust fixes completed:

- Rex Brain language now treats the simple MVP flow as the active production brain.
- Old-chat recall is explicit, all-chat, and degradation-aware.
- Search failure is reported as unavailable/degraded instead of "nothing was found."
- Memory updates and structured memory writes require durable backend confirmation.
- Unclear voice/location transcript fragments are blocked from direct memory writes.
- Saved memory and chat search results stay separate.
- Context remains capped and intent-guided for the low-token MVP flow.
- The Chats tab has a simple search surface backed by the conversation search endpoint.
- Saved memory categories include People, Events, Places, Goals, Preferences, Facts, and fallback Other.
- Manual testing recall gaps were addressed: Rex now searches generic topic terms and gives Grok nearby old-conversation context for related details like "send her money" near a birthday mention or game/games/PC-game discussions.
- Chat search trust coverage includes user-scoped Supabase transport tests for search and conversation context fetches.

### Issue 1A: Align Memory Model With Final Saved = Memory Rules

Status:
Complete.

[Added after latest Rex Brain audit against `docs/brain/REX_BRAIN_RULES.md` and `docs/brain/REX_BRAIN_ARCHITECTURE.md`]

Issue:
The final brain docs are strict: saved memory is the only durable memory, chat search results are only chat history, and anything Rex saves must be categorized and visible in Knows.

Files:
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\chat_context_service.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\prompt_memory_context.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\prompt_constants.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\action_truth_policy.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\chat_service.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\models\memory.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\long_term_memory_repository.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\memory_service.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\memory_intent_service.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\memory_turn_service.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\supabase_schema.sql`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\apps\mobile\lib\rex\memory`
- Relevant tests under `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\tests`

Fix Needed:
- [Done] Remove the legacy chat pseudo-memory concept from production code, prompts, truth policy, and tests.
- [Done] Keep chat search results as a separate context source, not as memory-shaped records.
- [Done] Use prompt sections that clearly separate saved memory from chat search results.
- [Done] Ensure chat search results are described as chat history unless the user explicitly asks Rex to save something.
- [Done] Ensure anything Rex saves through the direct memory path becomes durable, backend-confirmed memory.
- [Done] Ensure saved memories are categorized into clear groups such as People, Events, Places, Goals, Preferences, Facts, or fallback Other.
- [Done] Ensure the Knows page only shows properly saved and categorized memory or approved structured memory records.
- [Done] Prevent hidden or automatic chat-content saving into memory.
- [Done] Deprecate or remove save-from-message paths that can turn ordinary chat text into memory without a clear memory action.
- [Done] Track saved memory and chat search separately enough for MVP truth enforcement, with degraded search handled explicitly.
- [Done] Update truth enforcement so Rex cannot say it searched chats and found nothing unless chat search actually succeeded and returned useful results.
- [Done] Add tests for "Do you know anything about my mom?", chat search separation, durable categorized memory, no hidden chat auto-save, degraded chat search, and Knows category visibility.

Goal After Fix:
Rex follows the final memory rule exactly: saved means durable categorized memory, chat search means searchable chat history, and the two are never blurred.

Priority:
Highest

### Issue 2: Memory Retrieval Can Silently Fail

Status:
Complete for Group 1.

[Merged from Rex Brain MVP Fix Plan: Group 2 Issue 3, Group 3 Issue 6]

Issue:
Memory retrieval was recently improved, but Rex can still appear confident when memory/chat search is incomplete, unavailable, not actually checked, or based only on weak keyword old-chat matching.

Files:
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\chat_context_service.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\memory_service.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\memory_retrieval_ranker.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\conversation_repository.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\prompt_memory_context.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\tests\test_chat_context_service.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\tests\test_memory_profile_recall.py`

(Note: Experimental Rex Brain files are outside the MVP production path. Do not expand work here unless it strengthens the single simple MVP flow.)

Fix Needed:
- Keep memory and old-chat retrieval explicit for people, family, places, events, goals, and preferences.
- Label chat search results as chat history, not saved memory.
- Search old chats with safer fallback queries for family/date/relationship questions.
- Search across all user chats when the user asks about past information.
- Include the current conversation.
- Search beyond the recent message window.
- Keep search results short and relevant before adding them to the prompt.
- Replace silent empty-memory fallbacks with degraded context when memory/chat search fails.
- Make Rex distinguish between "I searched and found nothing" and "I could not access memory."
- Keep validating questions like "Do you know anything about my mom?" and "What do you know about me?"
- Add tests for degraded memory and degraded old-chat search.

Goal After Fix:
Rex only says it does not know when memory search actually succeeded and found nothing. If search fails, Rex clearly says memory is unavailable or degraded.

Priority:
High

### Issue 2A: Old-Chat Recall Must Be Conversation-Level, Not Keyword-Fragile

Status:
Complete.

[Added after manual Rex Brain recall audit on 2026-06-16]

Issue:
Manual testing showed Rex can recall details when the user opens the exact old conversation, but can fail from another chat. It can also find one keyword detail, such as mom's birthday, while missing related details from the same old conversation, such as sending her money or a gift. This proves old-chat recall is still too keyword-fragile and can behave like a targeted patch instead of a smart Rex Brain capability.

Current failure examples:
- Rex finds "your mom's birthday is June 18" but misses nearby "send her money" / gift intent from the same chat.
- Rex says there are no games or PC games even though an old chat includes first PC game, League of Legends, and Legacy of Kain.
- Rex can answer correctly after the user opens the old game chat because current conversation context is loaded, but cannot reliably find the same facts from another chat.
- Follow-ups like "Did I mention anything else about that?" need the previous subject and broader old-chat context, not only the literal word "that."

Files:
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\chat_context_service.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\conversation_repository.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\prompt_memory_context.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\prompt_constants.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\tests\test_chat_context_service.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\tests\test_memory_profile_recall.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\tests\test_chat_service.py`

Fix Needed:
- [Done] Remove one-off mom/birthday-specific query patches that make recall look hardcoded.
- [Done] Add generic query expansion for common recall cases: singular/plural terms, simple stemming, people, family, games, places, events, goals, preferences, work, and money-related details.
- [Done] When old-chat search finds a relevant message, retrieve enough surrounding conversation context for Grok to infer related details from the same topic.
- [Done] Prefer conversation-level clusters over isolated message snippets when the user asks broad recall questions.
- [Done] Preserve low-token behavior by ranking and capping the final prompt section, not by cutting context too early.
- [Done] Track whether old-chat search used exact keyword matches, expanded keyword matches, or conversation context.
- [Done] Strengthen follow-up handling so "that," "anything else," "what else," and "the chat" reuse the previous subject.
- [Done] Keep saved memory and chat search separate. Do not turn old chats into memory unless the user explicitly asks Rex to save something and the backend confirms it.
- [Done] Keep truth enforcement strict: if recall context is partial or degraded, Rex must not say "that's all" or "nothing else" with false certainty.

Required Tests:
- [Done] Mom birthday plus "send her money" / gift intent in the same old conversation.
- [Done] "Did I mention anything else about that?" after a mom recall answer.
- [Done] Game/games/PC game recall across old chats, including League of Legends and Legacy of Kain.
- [Done] Recall from another chat should match what Rex can answer when the original chat is opened.
- [Done] Generic recall for person, place, preference, event, goal, work, and money topics.
- [Done] No old-chat recall result should appear as saved memory or on the Knows page unless explicitly saved.

Goal After Fix:
Rex can search old chats as real conversation history. If the user previously discussed a topic, Rex should find the relevant old conversation, summarize all useful related details from that conversation, and label the answer as coming from chat history rather than saved memory.

Priority:
Highest

### Issue 3: Rex Can Claim Memory Updates Without Durable Confirmation

Status:
Complete for Group 1.

[Merged from Rex Brain MVP Fix Plan: Group 4 Issue 7]

Issue:
Rex can claim memory updates were saved, corrected, or deleted even when the backend did not confirm the durable write. Bad voice transcripts can also create or preserve nonsense memory rows.

Files:
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\memory_intent_service.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\memory_turn_direct_helpers.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\memory_correction_service.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\memory_discipline_service.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\tests\test_memory_turn_service.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\tests\test_chat_simple_memory_flow.py`

(Note: Experimental Rex Brain files are outside the MVP production path. Only the direct memory path matters for durable memory writes.)

Fix Needed:
- Require backend confirmation before Rex says a fact was saved, updated, corrected, or deleted.
- Make corrections update the visible "What Clarity Knows" record.
- Block unclear voice/location fragments from being saved as memory.
- Archive or supersede obviously corrupted location facts when a clean location correction is confirmed.
- If a memory write fails, Rex must say it failed instead of pretending it worked.
- Keep risky actions pending until confirmation.
- Say clearly when an action is unsupported.
- Keep post-processing small and focused on false success claims.
- Add/keep tests for city correction, birthday memory, and reminder-style memory.

Goal After Fix:
When Rex says it saved or fixed memory, the user can immediately see that change reflected in the app.

Priority:
High

### Issue 4: Rex Action Truth Is Still Risky

Status:
Complete for Group 1.

[Merged from Rex Brain MVP Fix Plan: Group 4 Issue 7]

Issue:
Rex action truth is still risky because advertised actions may not match what the backend can actually execute.

Files:
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\apps\mobile\lib\rex\data\financial_context_service.dart`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\clarity_control_service.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\rex_intent_router.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\chat_service.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\prompt_constants.py`

Fix Needed:
- Audit every action Rex can mention, suggest, or route.
- Remove unsupported actions from prompts and context.
- Require user confirmation before risky or durable actions.
- Require backend confirmation before success language.

Goal After Fix:
Rex only offers actions the app can actually execute, and never fakes completion.

Priority:
High

### Issue 4b: Experimental Rex Brain Routing Deferred - Use MVP Flow Only (Launch Scope Lock)

Status:
Complete for Group 1.

[Merged from Rex Brain MVP Fix Plan: Group 1 Issue 1, Group 5 Issue 9]

This is the final Group 1 item required before any Group 2 work or launch validation. It makes the orchestration simple so the trust fixes in Issues 2-4 are easy to reason about, test, and ship fast.

Issue:
The experimental Rex Brain layer (router, decision builder, brain-specific context selection/budgeting, per-layer prompt contracts, rollout machinery) is a large parallel system next to the simple MVP flow. It increases test surface, maintenance cost, and risk of subtle truth violations.

For fast MVP launch we lock to one simple brain:

- Always run direct memory + goal short-circuits first.
- One context assembly (chat_context_service).
- One prompt build (prompt_service + MEMORY_DISCIPLINE_PROMPT + personality).
- Post-LLM truth enforcement (action_truth_policy + clarity_action_parser) on every generated response.
- Model choice limited to static config (GROK_FAST_MODEL / standard) or explicit user "deep think" hints; no dynamic multi-layer routing.

Files (minimal surface for this item):
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\chat_service.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\chat_context_service.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\prompt_constants.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\prompt_service.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\config.py`
- `services/rex-api/.env.example` and `mobile.env.example`
- `services/rex-api/README.md`
- Relevant brain files may stay in tree but must not be called from the main chat/stream paths for launch.

Fix Needed (small, contained, 1-3 focused changes):
- In the primary `message` and `stream_message` paths: keep the memory_turn + goal short-circuits. Remove or make no-op the calls to `rex_brain_chat_service.safe_plan_chat_turn`, `apply_chat_contract`, brain `prompt_context` reshaping, and `build_prompt_messages_for_rex_brain`.
- Always fall through to the standard `chat_context_service` + `prompt_service.build_messages` path + existing truthful post-processing.
- Update config/env so experimental routing cannot create a second production brain for MVP.
- Merge the strongest reusable safety language from the brain layer prompts ("admit when memory/context missing", "never claim action without execution metadata", etc.) into the single base `MEMORY_DISCIPLINE_PROMPT` and `REX_PERSONALITY_PROMPT`.
- Verify (tests + manual + smoke): only the base two-path orchestration is active. Advanced brain planning must not affect any launch response.
- Update README and any readiness notes to state "MVP uses one simple Rex Brain flow; experimental routing is not part of the production path."

Goal After Fix:
One simple, trustworthy orchestration path for the entire MVP. All Group 1 truth guarantees are easy to maintain. Launch validation, Group 2 polish, and prod smoke tests have minimal surface area. The advanced brain system can be revisited cleanly after real users are on the reliable base.

Priority:
High (complete this before declaring Group 1 done and moving to Group 2)

### Issue 4c: Simplify To One Production Rex Brain

Status:
Complete for Group 1.

[Merged from Rex Brain MVP Fix Plan: Group 1 Issue 1, Group 5 Issue 9]

Issue:
The code and docs still carry the shape of two systems: a simple production path and a heavier experimental brain. This makes the MVP harder to reason about and creates confusion about what Rex is actually using.

Files:
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\simple_rex_brain.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\chat_service.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\chat_context_service.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\prompt_service.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\rex_brain_chat_service.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\rex_model_router.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\config.py`
- `services/rex-api/.env.example`
- `services/rex-api/mobile.env.example`
- `services/rex-api/README.md`
- Relevant tests that still say production routing is disabled or base-only

Fix Needed:
- Treat the current production path as the MVP Rex Brain.
- Stop describing the production brain as disabled or base-only.
- Keep experimental routing clearly labeled and outside the production chat and voice path.
- Make chat and voice use the same simple flow.
- Remove or rename confusing test/readiness language.
- Keep the production brain easy to trace from user message to Rex response.
- Reuse experimental brain ideas only when they fit the simple MVP flow.

Goal After Fix:
There is one Rex Brain for MVP. It is active, simple, and understandable.

Priority:
High

### Issue 4d: Keep Rex Brain Lightweight And Low-Token

Status:
Complete for Group 1.

[Merged from Rex Brain MVP Fix Plan: Group 1 Issue 2, Group 5 Issue 8]

Issue:
Rex Brain can drift into too many layers, contracts, routing decisions, and context blocks. That increases token usage, slows responses, and makes manual errors more likely.

Files:
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\simple_rex_brain.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\chat_service.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\chat_context_service.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\prompt_service.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\prompt_constants.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\tests\test_chat_prompt_context.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\tests\test_chat_context_service.py`

Fix Needed:
- Use a small intent check only to decide context.
- Fetch minimal relevant context.
- Let Grok do the reasoning.
- Keep truth enforcement focused on the highest-risk claims.
- Avoid large prompt contracts unless they directly improve reliability.
- Keep default context small.
- Retrieve only context related to the current intent.
- Prefer short chat search result snippets over full conversations.
- Cap chat search results before prompt assembly.
- Avoid loading broad structured context unless needed.
- Add tests or assertions for token/context discipline.

Goal After Fix:
Rex Brain stays fast, cheap, maintainable, and easier to debug.

Priority:
High

### Issue 4e: Saved Memory And Chat Search Results Must Stay Separate

Status:
Complete for Group 1.

[Merged from Rex Brain MVP Fix Plan: Group 3 Issue 5]

Issue:
Rex needs to use old chat history without pretending it is saved memory. The user-visible "What Clarity Knows" screen should only show confirmed, categorized saved memory. Chat search results should be used only as chat history unless the user explicitly asks Rex to save something.

Files:
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\chat_context_service.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\prompt_memory_context.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\prompt_constants.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\memory_service.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\apps\mobile\lib\rex\memory`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\tests\test_memory_profile_recall.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\tests\test_chat_context_service.py`

Fix Needed:
- Label saved memory and chat search results in separate prompt sections.
- Tell the user when an answer came from chat history instead of saved memory.
- Do not show unsaved chat content in "What Clarity Knows."
- Save a chat detail only when the user explicitly asks Rex to save it or a clear memory-save action is confirmed.
- When saved, the detail must become durable categorized memory.
- Keep saved memory editable and user-visible.

Goal After Fix:
Rex can recall through chat search without polluting saved memory or creating hidden memory.

Priority:
High

### Issue 4f: Chat Search Must Be User-Visible

Status:
Complete for Group 1.

[Merged from Rex Brain MVP Fix Plan: Group 2 Issue 4]

Issue:
Rex may search chat history internally, but the user also needs a simple way to search old chats from the Chats tab.

Files:
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\routes\conversations.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\conversation_repository.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\apps\mobile\lib\rex\chat\data\conversation_api.dart`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\apps\mobile\lib\rex\chat\application\conversation_controller.dart`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\apps\mobile\lib\rex\chat\presentation\pages\conversation_list_page.dart`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\apps\mobile\lib\rex\chat\presentation\widgets\conversation_history_widgets.dart`

Fix Needed:
- Add or finish the backend conversation message search endpoint.
- Add simple search UI to the Chats tab.
- Search conversation titles and message content.
- Show conversation, date, and matching message preview.
- Keep the MVP UI practical: search box, result list, empty state, and tap to open conversation.
- Use the same backend search behavior Rex uses where possible.

Goal After Fix:
The user and Rex can both search chat history from the same source of truth.

Priority:
High

## Group 2: UX Polish & Usability

### Issue 5: Manage Categories Scroll Bug

Issue:
Manage Categories cannot reliably scroll to all saved categories on device.

Files:
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\apps\mobile\lib\features\budgets\presentation\budgets_screen.dart`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\apps\mobile\lib\features\budgets\presentation\category_management_sheet.dart`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\apps\mobile\lib\features\budgets\presentation\category_management_sheet_sections.dart`

Fix Needed:
- Rework the category management modal so content has one predictable scroll container.
- Verify the list reaches the final category on small iPhone screens.
- Keep tabs and the add button usable without blocking list scroll.

Goal After Fix:
Users can open Manage Categories and scroll through every saved category without layout traps.

Priority:
High

### Issue 6: Account Cards Are Still Too Crowded

Issue:
Account cards still feel crowded and can make account identity hard to read.

Files:
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\apps\mobile\lib\core\models\account.dart`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\apps\mobile\lib\features\accounts\presentation\widgets\plaid_account_header.dart`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\apps\mobile\lib\features\accounts\presentation\widgets\plaid_account_tile.dart`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\apps\mobile\lib\features\accounts\presentation\accounts_screen.dart`

Fix Needed:
- Keep the shared display name format: institution + account type + mask.
- Give the account title more horizontal space.
- Move secondary metadata and actions so they do not crowd the account name.
- Verify the same display name is used by Rex and the UI.

Goal After Fix:
Users can instantly recognize each account, and Rex uses the exact same account names.

Priority:
High

### Issue 7: Dashboard Controls And Spacing Need Polish

Issue:
Dashboard still has unnecessary controls and spacing that make the financial area feel unpolished.

Files:
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\apps\mobile\lib\features\dashboard\presentation\financial_dashboard_shell.dart`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\apps\mobile\lib\features\dashboard\presentation\financial_dashboard_transaction_controls.dart`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\apps\mobile\lib\features\dashboard\presentation\financial_dashboard_transactions.dart`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\apps\mobile\lib\features\dashboard\presentation\dashboard_screen.dart`

Fix Needed:
- Reduce empty space above the Overview section.
- Remove unnecessary Budgets shortcut from the dashboard overview.
- Remove or hide the Rows transaction mode unless it is truly needed.
- Keep Months and Categories as the primary transaction views.

Goal After Fix:
The dashboard feels intentional, compact, and launch-ready.

Priority:
High

### Issue 7A: Voice UI Must Be One Feature, Not Two Separate Experiences

Issue:
Manual testing showed voice feels like two different features. Starting voice from the Chat tab keeps the call inside the chat with an inline voice panel. Opening the Voice tab shows a separate full-screen voice interface. Backend voice mostly routes through the same chat brain, but the mobile UI makes voice feel split and inconsistent.

Files:
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\apps\mobile\lib\rex\presentation\assistant_screen.dart`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\apps\mobile\lib\rex\chat\presentation\pages\chat_page.dart`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\apps\mobile\lib\rex\chat\presentation\widgets\inline_voice_call_panel.dart`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\apps\mobile\lib\rex\voice\presentation\pages\voice_chat_page.dart`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\apps\mobile\lib\rex\voice\presentation\widgets\voice_call_controls.dart`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\apps\mobile\lib\rex\voice\application\voice_call_controller.dart`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\routes\voice.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\voice_stream_session.py`

Fix Needed:
- Decide the MVP voice product shape: voice should be one mode of the same assistant conversation, not a separate assistant.
- Make the Voice tab and Chat call button use the same active conversation and the same visible call state.
- Avoid two different voice layouts with different behavior unless one is only a presentation wrapper around the same call mode.
- If the Voice tab remains, make it clearly open/start the same chat voice call rather than creating a separate-feeling feature.
- Ensure voice transcripts and assistant replies are saved into the same conversation shown in Chat and Chats.
- Keep backend voice on the same `chat_service.send_message` Rex Brain path.
- Add manual tests for starting voice from Chat, switching to Voice, returning to Chat, and confirming the conversation/history remains consistent.

Goal After Fix:
Voice feels like one Rex conversation mode. The user should not have to understand two different voice systems.

Priority:
High

### Issue 7B: Arbitrary Chat Recall Hardening

[Added after Rex Brain search audit against `docs/brain/REX_BRAIN_RULES.md`, `docs/brain/REX_BRAIN_ARCHITECTURE.md`, and `docs/brain/REX_BRAIN_HYBRID_CHAT_SEARCH.md`]

Issue:
Group 1 fixed the biggest old-chat recall failures, but current recall is still keyword-based. For a multi-user app, users can ask Rex about anything: family, games, plans, work, immigration, purchases, places, friends, money, or any personal topic. The MVP keyword layer needs more generic hardening before it can be trusted as the baseline for arbitrary recall.

Current Alignment:
- Rex searches chat history separately from saved memory.
- Rex uses generic keyword expansion instead of one-off mom/birthday patches.
- Rex retrieves conversation-level context around matches.
- Rex reports degraded chat search through memory status.
- Supabase transport scopes authenticated reads/writes by `user_id`.
- Migrations define user-scoped conversations/messages with RLS.

Remaining Gaps:
- Search ranking is still basic and not clearly scored by exact match, user-authored content, recency, repeated mentions, and conversation relevance.
- Query expansion is duplicated between Rex internal recall and user-visible Chats search.
- Alias coverage is still manual and limited, so arbitrary topics may miss unless the user repeats similar wording.
- Conversation clusters are useful, but there is no explicit score explaining why one old conversation outranked another.
- Service-layer tests now prove message search, conversation search, and conversation message context fetches are scoped by authenticated `user_id`; broader ranking and shared result-shaping tests still need work.
- `services/rex-api/supabase_schema.sql` is stale compared with migrations and does not show the current user-scoped assistant tables.
- The user-visible Chats tab search and Rex internal recall share repository behavior, but their ranking/result shape is not fully unified.

Files:
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\chat_context_service.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\conversation_repository.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\supabase_memory_transport.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\routes\conversations.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\prompt_memory_context.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\supabase_schema.sql`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\supabase\migrations\000010_create_rex_assistant_tables.sql`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\tests\test_chat_context_service.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\tests\test_conversation_routes.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\tests\test_user_scoped_memory_service.py`

Fix Needed:
- Create one reusable keyword expansion/ranking helper used by both Rex internal recall and user-visible Chats search.
- Add explicit scoring for exact matches, expanded matches, user-authored messages, recency, repeated mentions, and conversation-level relevance.
- Return or log search status with enough detail to know whether exact, expanded, or conversation-context search found the result.
- Add broad arbitrary-topic tests beyond family/birthday/games: people, places, purchases, work, immigration, preferences, goals, money, and objects.
- Add broader multi-user tests around ranked result shaping after the reusable search helper exists.
- Refresh `services/rex-api/supabase_schema.sql` so the documented schema matches the user-scoped migrations.
- Keep prompt context capped and labeled as chat history, not saved memory.
- Keep degraded/no-result truth enforcement unchanged: Rex must not say "nothing came up" unless search actually completed.

Goal After Fix:
Rex has a trustworthy MVP keyword recall baseline for arbitrary user topics. It is still not semantic search, but it is user-scoped, ranked, generic, test-covered, and honest.

Priority:
High

### Issue 11: Rex And Finance Use Separate Visual Token Systems

Issue:
Rex and finance screens still use separate visual token systems.

Files:
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\apps\mobile\lib\app\app.dart`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\apps\mobile\lib\rex\presentation\rex_ui_tokens.dart`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\apps\mobile\lib\rex\presentation\rex_surfaces.dart`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\apps\mobile\lib\features\dashboard\presentation\financial_dashboard_view.dart`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\apps\mobile\lib\features\accounts\presentation\accounts_screen.dart`

Fix Needed:
- Make Rex surfaces and financial screens share one practical dark design system.
- Keep spacing, card borders, typography, and accent colors consistent.
- Avoid making Rex feel polished while finance feels separate.

Goal After Fix:
Clarity feels like one app, with Rex and finance using the same visual language.

Priority:
Medium

## Group 3: Nice-to-Have

### Issue 8: Chats Tab Needs Search And Better Organization

Search work for this issue has been promoted into Group 1 as Issue 4f because it is part of Rex Brain trust and old-chat recall. This Group 3 item now tracks only extra organization polish after the high-priority search work is complete.

Issue:
Chats tab is hard to use for old conversations.

Files:
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\apps\mobile\lib\rex\chat\presentation\pages\conversation_list_page.dart`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\apps\mobile\lib\rex\chat\presentation\widgets\conversation_history_widgets.dart`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\apps\mobile\lib\rex\chat\application\conversation_list_controller.dart`

Fix Needed:
- Complete Group 1 Issue 4f first for search by conversation title and message text.
- Improve grouping by date with clear day, month, and year labels.
- Avoid messy endless lists by adding better sectioning and empty states.

Goal After Fix:
Users can find old Rex conversations quickly and trust that past context is accessible.

Priority:
Medium

### Issue 9: PDF Upload Is Not Supported

Issue:
PDF upload is not supported in Rex attachments.

Files:
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\apps\mobile\lib\rex\chat\domain\chat_attachment.dart`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\apps\mobile\lib\rex\chat\presentation\pages\chat_page.dart`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\file_service.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\routes\chat.py`

Fix Needed:
- Add PDF as an allowed attachment type or explicitly defer it from MVP.
- If included, extract text safely on the backend and enforce file-size limits.
- Show clear upload errors when a PDF cannot be read.

Goal After Fix:
Users can attach images and PDFs, or the app clearly communicates that PDFs are not part of MVP.

Priority:
Medium

### Issue 10: Voice Feels Slow And Robotic

Issue:
Voice feels slow and robotic.

Files:
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\apps\mobile\lib\rex\voice\application\voice_call_controller_streaming.dart`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\apps\mobile\lib\rex\voice\data\streaming_audio_playback_queue.dart`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\voice_stream_session.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\voice_stream_response_writer.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\google_tts_service.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\config.py`

Fix Needed:
- Measure first-audio latency and full response latency.
- Tune chunking so Rex starts speaking sooner.
- Adjust speech rate and voice settings for a more natural pace.
- Add a safe fallback when streaming voice fails.

Goal After Fix:
Voice feels responsive enough for daily use and does not sound painfully slow.

Priority:
Medium

### Issue 10B: Hybrid Chat Search For Arbitrary User Recall

[Future retrieval work from `docs/brain/REX_BRAIN_HYBRID_CHAT_SEARCH.md`]

Issue:
Keyword search cannot fully support arbitrary user recall. Users may ask with different wording than they used in the original chat. Manual aliases can help, but they will never cover everything people may discuss in a multi-user assistant app.

Examples:
- Old chat says "I intend to send her money around the 18th"; user later asks "Did I mention a gift?"
- Old chat says "EAD renewal"; user later asks "What did I say about immigration?"
- Old chat says "Legacy of Kain"; user later asks "What was the game I wanted?"

Files:
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\docs\brain\REX_BRAIN_HYBRID_CHAT_SEARCH.md`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\chat_context_service.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\conversation_repository.py`
- Future embedding/indexing service and migration files

Fix Needed:
- Add semantic indexing for user messages or conversation summaries.
- Keep all indexes strictly user-scoped.
- Combine keyword results and semantic results into one ranked result set.
- Rank by same user, exact keyword match, semantic similarity, user-authored messages, conversation relevance, recency, and repeated mentions.
- Retrieve conversation-level context around selected results.
- Keep chat history separate from saved memory.
- Keep prompt context short and labeled.
- Add tests where the user's recall wording differs from the original chat wording.

Goal After Fix:
Rex can search old chats intelligently across arbitrary topics, not only through exact or aliased keywords.

Priority:
Medium

## Group 4: Technical Debt (Do Last)

### Issue 12: Large App-Critical Files Increase Launch Risk

Issue:
Large app-critical files make launch fixes risky.

Files:
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\apps\mobile\lib\app\ui_dependencies.dart`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\apps\mobile\lib\features\transactions\presentation\widgets\transaction_category_dropdown.dart`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\apps\mobile\lib\features\dashboard\presentation\transaction_review_screen.dart`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\apps\mobile\lib\rex\data\financial_context_service.dart`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\chat_context_service.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\memory_intent_service.py`
- `C:\Users\admin\Documents\Codex\2026-06-15\we-re-coming-from-a-mac\work\clarity-rex\services\rex-api\app\services\chat_service.py`

Fix Needed:
- Do not do broad refactors before fixing user-facing trust bugs.
- After high-priority issues are fixed, split only the files directly blocking safe development.
- Start with context/memory/financial files because they affect Rex truth.

Goal After Fix:
The app remains stable for MVP while the riskiest files become easier to maintain.

Priority:
Low
