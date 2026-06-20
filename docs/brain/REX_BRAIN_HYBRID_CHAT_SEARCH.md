# REX_BRAIN_HYBRID_CHAT_SEARCH.md

## 1. Purpose

Hybrid Chat Search is the future recall layer for Rex Brain.

Its job is to help Rex find relevant user chat history across arbitrary topics, not only known MVP subjects.

This is not a second brain. It is an improved retrieval layer inside the same Rex Brain flow.

This is post-launch direction. Launch uses the simpler keyword recall path documented in `REX_BRAIN_FINAL_RESET.md`; broader hybrid retrieval work belongs in `REX_BRAIN_POST_LAUNCH.md`.

## 2. Product Goal

Users should be able to ask Rex about anything they have discussed before.

Examples:
- "What did I say about my mom?"
- "Do you remember the game I wanted to buy?"
- "Search chats about my immigration plan."
- "What did I say about payroll?"
- "Did I mention a gift?"
- "What was that place I talked about?"

Rex should search the user's own chats, find the most relevant conversations, summarize useful details, and clearly say the answer came from chat history.

## 3. Non-Negotiable Rules

- Search must be strictly user-scoped.
- Rex must never search or expose another user's chats.
- Chat search results are not saved memory.
- Chat search must not automatically create memory.
- Saved memory still requires explicit save intent and backend confirmation.
- The Knows page must only show saved categorized memory, not chat search results.
- Rex must report degraded or unavailable search honestly.

## 4. MVP Baseline

The MVP baseline is strong keyword search.

It should:
- Search all chats for the current user.
- Include old conversations and the current conversation.
- Use generic keyword expansion, not hardcoded topic patches.
- Handle singular and plural terms.
- Use common aliases for family, games, places, work, money, goals, preferences, and events.
- Return conversation-level context instead of isolated one-line snippets.
- Keep prompt context capped and relevant.

This is enough for MVP if it is reliable, honest, and easy to debug.

## 5. Future Hybrid Search

Hybrid search should combine:
- Keyword search
- Semantic search
- Conversation clustering
- Result ranking
- Source status tracking

Keyword search is good for exact terms.

Semantic search is needed when the user asks with different words than they used before.

Example:
- Old chat: "I intend to send her money around the 18th."
- User asks later: "Did I mention a gift for my mom?"

Keyword search may miss that unless aliases cover it. Semantic search should make that easier without endless manual aliases.

## 6. Ranking Rules

Hybrid search should rank results by:
- Same authenticated user
- Exact keyword match
- Semantic similarity
- User-authored messages
- Conversation-level relevance
- Recency
- Repeated mentions
- Relationship to the user's latest question
- Whether the result is a failed old Rex response that should be ignored

Rex should prefer useful conversation clusters over isolated messages.

## 7. Prompt Rules

Hybrid search should send Grok only the best context.

Prompt context should include:
- A short label that results are chat history
- Conversation date or age when available
- The useful nearby messages
- Enough surrounding turns to understand the topic
- A clear status if search was partial or degraded

Prompt context should not include long raw transcripts unless the user explicitly asks for detail.

## 8. User-Facing Behavior

Good:
- "I found this in chat history, not saved memory."
- "I found a chat where you said you planned to send her money around the 18th."
- "I found a few related chats. The useful details are..."
- "Chat search is unavailable right now, so I cannot confidently answer from old chats."

Bad:
- "I know that" when it only came from chat search.
- "Nothing came up" when search was degraded.
- "I saved that" when Rex only found it in chat history.
- Searching only recent messages and calling it long-term recall.

## 9. Implementation Direction

Recommended path:
- Keep the current keyword search stable for MVP.
- Add better reusable query expansion over time.
- Add conversation-level ranking and deduplication.
- Add embeddings or another semantic index for user messages and conversation summaries.
- Use hybrid ranking: keyword first, semantic second, conversation context final.
- Keep source status and truth enforcement simple.
- Add tests with arbitrary user topics, not only family or birthday examples.

Hybrid Chat Search strengthens the same Rex Brain. It must not become a separate memory system or a second assistant.
