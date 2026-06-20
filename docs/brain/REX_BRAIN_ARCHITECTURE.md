# REX_BRAIN_ARCHITECTURE.md

## 1. Overview

Rex Brain is one simple assistant flow for MVP.

The goal is not to build a complex brain system. The goal is to give Grok the right context, keep Rex honest, and make the code easy to debug.

Grok does the reasoning. Rex Brain handles context, backend-confirmed actions, and truth boundaries.

Launch production path: `ChatService` uses `SimpleRexBrain` for both typed chat and voice. Layered `rex_brain_*` modules are non-production experiments and must not be treated as the launch brain.

Pre-launch cleanup is recorded in `REX_BRAIN_FINAL_RESET.md`; larger entity migration, richer cards, hybrid search, and advanced routing live in `REX_BRAIN_POST_LAUNCH.md`.

## 2. MVP Flow

```text
User message
  -> Simple intent check
  -> Minimal context fetch
  -> Optional direct backend action
  -> Short prompt to Grok
  -> Light truth check
  -> Rex response
```

This is the production brain for MVP.

Advanced routing, model selection, and deeper planning can be added later only if they plug into this same flow.

## 3. Step 1: Simple Intent Check

The intent check should stay lightweight.

It only decides what context is needed for this turn.

Main MVP intents:
- Normal chat
- Save memory
- Update memory
- Recall memory or search chats
- Goal or commitment
- Finance
- File question
- Unknown

The intent check should not become a second reasoning system.

## 4. Step 2: Minimal Context Fetch

Context fetch gives Grok the smallest useful set of facts.

Possible context sources:
- Recent conversation messages
- Relevant saved memory
- Relevant chat search results when the user asks for recall
- Goals and commitments
- Financial context
- Uploaded file context
- Current time context

Each source should have a simple status:
- Searched and found results
- Searched and found nothing
- Unavailable or degraded

A failed source is not proof that the user never said something.

## 5. Step 3: Optional Direct Backend Action

Some simple actions can happen before Grok answers.

Examples:
- Save a clear memory
- Update a clear memory correction
- Save a clear goal or commitment

These actions must be deterministic and backend-confirmed.

If the backend does not confirm the write, Rex must not claim success.

Anything Rex saves is durable memory. There should be no hidden or temporary save path that does not create a categorized memory record.

Risky or unclear actions should not happen automatically. Rex should ask for confirmation or clarification.

## 6. Step 4: Short Prompt To Grok

The prompt should be short, labeled, and useful.

It should include:
- Short Rex behavior rules
- Relevant saved memory
- Relevant chat search results when the user asks for recall
- Relevant financial context
- Recent conversation context
- The user's latest message

Chat search results must be labeled as chat search results, not saved memory.

Do not send large context blocks by default. Token usage matters.

## 7. Step 5: Grok Response

Grok writes the natural answer.

Rex should rely on Grok for language, judgment, and reasoning once the right context is loaded.

Grok must not invent saved memories, financial numbers, completed actions, or unavailable search results.

## 8. Step 6: Light Truth Check

The final check is small and practical.

It should catch the highest-risk mistakes:
- Claiming an action succeeded without backend confirmation
- Claiming a memory was saved without backend confirmation
- Treating chat search results as saved memory
- Saying search found nothing when search failed
- Claiming financial facts not present in context

This check is a safety net. It should not become a large second brain.

## 9. Saved Memory vs Chat Search

Saved memory:
- Explicitly saved and backend-confirmed memory record
- Categorized as People, Events, Places, Goals, Preferences, Facts, or another clear memory group
- Moving entity-first, with basic Person cards supported at launch and flat memories retained as fallback
- User-visible in "What Clarity Knows"
- Editable and deletable
- Treated as Clarity knowledge

Chat search:
- Strong keyword search across all user chats
- Includes old conversations and the current conversation
- Used when the user asks recall questions such as "Do you remember...", "What did I say about...", "Search chats about...", or "Do you know anything about my mom?"
- Not saved memory
- Not automatically shown in "What Clarity Knows"
- Must be described as chat history unless the user explicitly saves something as memory

There should be no automatic or hidden saving of chat content into memory.

Rex should use saved memory and chat search differently, and label them clearly.

Future retrieval work should follow `docs/brain/REX_BRAIN_HYBRID_CHAT_SEARCH.md`: hybrid keyword plus semantic search, conversation-level ranking, strict user scoping, and clear chat-history labeling.

## 10. Chat And Voice

Chat and voice use the same Rex Brain flow.

Voice has a different input format, but the same memory rules, action rules, context rules, and truth policy.

Voice can be more cautious because transcripts can be imperfect.

## 11. Future Advanced Work

Advanced brain work is allowed later, but it must not create a second production brain.

Future improvements should stay inside the same simple flow:
- Better intent checks
- Better search ranking
- Hybrid Chat Search for arbitrary user recall
- Entity-based memory enhancements for People, Places, Events, Goals, and Preferences
- Better prompt budgeting
- Better source status tracking
- Better truth checks

Keep future improvements, including Hybrid Chat Search and entity memory, inside the same simple flow. They must not create a second brain, a separate memory system, or large context/prompt god files.

The MVP architecture stays simple.
