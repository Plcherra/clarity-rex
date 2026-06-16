# REX_BRAIN_MVP_FIX_PLAN.md

Archived: this plan has been fully merged into `docs/mvp-fix-plan.md`. Keep this file only as historical reference. The active MVP fix plan is `docs/mvp-fix-plan.md`.

This plan simplifies Rex Brain for MVP.

The goal is to launch with one reliable assistant flow that uses low tokens, good context, Grok's intelligence, and light truth enforcement.

## Group 1: Simplify To One Production Brain

### Issue 1: Rex Brain Still Feels Too Complicated

Problem:
The code and docs still carry the shape of a heavier advanced brain. This makes the MVP harder to reason about and creates confusion about what Rex is actually using.

Fix Needed:
- Treat the current production path as the MVP Rex Brain.
- Stop describing the production brain as disabled or base-only.
- Keep advanced routing experimental and outside the MVP path.
- Make chat and voice use the same simple flow.
- Remove or rename confusing test/readiness language.
- Keep the production brain easy to trace from user message to Rex response.

Goal:
There is one Rex Brain for MVP. It is active, simple, and understandable.

Priority:
Highest

### Issue 2: The Brain Should Not Become A Heavy Orchestrator

Problem:
The architecture can drift into too many layers, contracts, and routing decisions. That increases token usage and makes manual errors more likely.

Fix Needed:
- Use a small intent check only to decide context.
- Fetch minimal relevant context.
- Let Grok do the reasoning.
- Keep truth enforcement focused on the highest-risk claims.
- Avoid large prompt contracts unless they directly improve reliability.

Goal:
Rex Brain stays maintainable and low-token.

Priority:
Highest

## Group 2: Strong Old Chat Search

### Issue 3: Rex Can Miss Facts That Exist In Chat History

Problem:
Rex may fail to recall information that exists in older conversations or earlier in the same conversation. This breaks trust because the user knows they already told Rex.

Fix Needed:
- Search across all user chats when the user asks about past information.
- Include the current conversation.
- Search beyond the recent message window.
- Use simple keyword and alias search for people, family, places, goals, and preferences.
- Keep search results short and relevant before adding them to the prompt.
- Add tests for questions like "Do you know anything about my mom?"

Goal:
If the user told Rex something in chat, Rex has a reliable way to find it later without loading massive chat history.

Priority:
Highest

### Issue 4: Chat Search Must Be User-Visible

Problem:
Rex may search chat history internally, but the user also needs a simple way to search old chats from the Chats tab.

Fix Needed:
- Add or finish the backend conversation message search endpoint.
- Add simple search UI to the Chats tab.
- Search conversation titles and message content.
- Show conversation, date, and matching message preview.
- Keep the MVP UI practical: search box, result list, empty state, and tap to open conversation.
- Use the same backend search behavior Rex uses where possible.

Goal:
The user and Rex can both search chat history from the same source of truth.

Priority:
High

## Group 3: Memory And Evidence Truth

### Issue 5: Saved Memory And Chat Search Results Must Stay Separate

Problem:
Rex needs to use old chat history without pretending it is saved memory.

Fix Needed:
- Label saved memory and chat search results separately in the prompt.
- Tell the user when an answer came from chat history instead of saved memory.
- Do not show unsaved chat content in "What Clarity Knows."
- Save a chat fact only when the user confirms or the save rule clearly applies.
- Keep saved memory editable and user-visible.

Goal:
Rex can remember through chat search without polluting saved memory.

Priority:
High

### Issue 6: Search Failure Must Not Look Like No Results

Problem:
A failed memory or chat search can look the same as a successful search with no results.

Fix Needed:
- Track simple source status for memory and old chat search.
- Tell Grok when a source is degraded.
- Prevent "I found nothing" responses when search failed.
- Add tests for degraded memory and degraded old chat search.

Goal:
Rex only says it did not find something when search actually worked.

Priority:
High

## Group 4: Action Truth

### Issue 7: Rex Must Never Fake Completed Actions

Problem:
Rex can sound like it saved, updated, deleted, sent, or completed something when the backend did not confirm it.

Fix Needed:
- Require backend confirmation for durable success language.
- Keep direct memory saves deterministic.
- Keep risky actions pending until confirmation.
- Say clearly when an action is unsupported.
- Keep post-processing small and focused on false success claims.

Goal:
When Rex says something happened, it really happened.

Priority:
High

## Group 5: Token And Maintenance Discipline

### Issue 8: Context Can Grow Too Large

Problem:
Large memory, chat, financial, or structured context makes Rex slower, more expensive, and easier to confuse.

Fix Needed:
- Keep default context small.
- Retrieve only context related to the current intent.
- Prefer short evidence snippets over full conversations.
- Cap chat search results before prompt assembly.
- Avoid loading broad structured context unless needed.

Goal:
Rex stays fast, cheap, and easier to debug.

Priority:
High

### Issue 9: Experimental Brain Code Must Not Confuse MVP

Problem:
Experimental advanced brain files may be useful later, but they should not define MVP behavior.

Fix Needed:
- Label experimental routing clearly.
- Keep it outside the production chat and voice path.
- Reuse useful ideas only when they fit the simple MVP flow.
- Prefer small, testable functions over large orchestration files.

Goal:
Rex Brain remains easy to understand, debug, and extend.

Priority:
Medium

## MVP Acceptance Checklist

Rex Brain is MVP-ready when:

- There is one documented production Rex Brain.
- Chat and voice use the same simple flow.
- The flow is easy to trace from user message to response.
- Rex uses minimal relevant context by default.
- Rex searches saved memory and old chats for recall questions.
- Rex searches across all chats, including the current conversation.
- Rex clearly labels saved memory and chat search results.
- Rex reports degraded search instead of pretending nothing exists.
- Rex only claims saved or completed actions after backend confirmation.
- The Chats tab has simple search for old conversations and messages.
- Tests cover memory recall, old chat recall, degraded search, action truth, and token discipline.
