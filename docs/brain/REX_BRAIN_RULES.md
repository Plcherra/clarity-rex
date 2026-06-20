# REX_BRAIN_RULES.md

## 1. Purpose

Rex Brain is the assistant system inside Clarity.

For MVP, Rex Brain should be simple. Its job is to give Grok the right context, keep memory and chat history honest, prevent fake completed actions, and answer from the same data Clarity shows the user.

Rex Brain is not a second app and not a heavy reasoning engine. Grok provides most of the intelligence. Clarity provides the data truth.

## 2. Core Rules

- Keep Rex Brain as small as possible.
- Use one production brain for chat and voice.
- Prefer good context over complex routing.
- Keep prompts short and relevant.
- Search saved memory and old chats when the user asks about past information.
- Clearly separate saved durable memory from chat search results.
- Never claim a durable action happened unless the backend confirms it.
- Say when memory, old chat search, financial data, or another source is unavailable or degraded.
- Use the same financial data the user sees in Clarity.
- Ask for confirmation before important, risky, destructive, or account-changing actions.

## 3. Memory Truth

Only things that Rex explicitly saves with backend confirmation become durable memory.

These saved memories must be organized into clear categories, such as People, Events, Places, Goals, Preferences, Facts, and other useful Clarity memory groups.

Only properly saved and categorized memories should appear in the "What Clarity Knows" / Knows page.

If Rex saves anything, it is memory. There should be no such thing as saving something that is not durable memory.

There should be no automatic or hidden saving of chat content into memory.

Old chat messages are not saved memory. Rex should not treat old chat messages as saved memory or confirmed Clarity knowledge unless the user explicitly asks to save them.

Rex can search chats when the user asks recall questions, but search results remain chat history unless the user explicitly saves something as memory.

Good:
- "I do not have that saved as memory, but I found a chat message where you said your mom's birthday is June 18."
- "I found this by searching chats. It is not saved memory."
- "I can save that as memory if you want."
- "I tried to search memory and old chats, but chat search is degraded right now."

Bad:
- "I know your mom's birthday is June 18" when it only came from chat search.
- "I do not know anything about your mom" when chat search failed or was not checked.
- "I saved that" when the backend did not confirm a saved memory record.
- Saving chat content automatically without a clear save action.

## 4. Old Chat Search

Old chat search is part of Rex Brain MVP.

Rex must be able to do strong keyword search across all user chats, including old conversations and the current one, when the user asks recall questions.

Recall questions include:
- "Do you remember..."
- "What did I say about..."
- "Search chats about..."
- "Do you know anything about my mom?"

When the user asks what Rex remembers, what they said, what Rex knows about a topic, or what was talked about before, Rex must search beyond the recent message window.

Old chat search should:
- Search all user chats, including the current conversation.
- Use simple keyword search first.
- Use aliases for common terms, such as mom, mother, mum, and mama.
- Return only the most useful chat matches for the current question.
- Avoid flooding the prompt with long chat history.
- Report clearly when search is unavailable or degraded.

Old chat search does not turn past messages into memory. Chat history is searchable history. Saved memory is explicit, durable, categorized knowledge.

Future work should evolve old chat search into Hybrid Chat Search for arbitrary user recall. See `docs/brain/REX_BRAIN_HYBRID_CHAT_SEARCH.md`.

## 5. Prompt And Token Rules

Rex Brain must protect token usage.

The prompt should include only what is useful for the current turn:
- Short Rex behavior rules
- Relevant saved memory
- Relevant chat search results when the user asks for recall
- Relevant financial context
- Recent conversation context
- The user's latest message

Do not load broad memory, long chat history, or large structured context unless the user asks for it or the intent clearly needs it.

If context is too large, prefer the most relevant and recent items.

## 6. Voice Rules

Voice and chat use the same Rex Brain.

Voice may add transcript caution, but it must not use a separate memory system, action system, or truth policy.

If a voice transcript is unclear, Rex should ask for clarification before saving a fact.

## 7. Action Truth

Rex must never fake completed actions.

Durable actions require backend confirmation before Rex uses success language.

Durable actions include:
- Saving, updating, or deleting memory
- Creating, updating, or deleting goals
- Changing transactions, accounts, categories, or budgets
- Sending reminders, notifications, messages, or external actions
- Any financial or account-changing operation

If an action is only proposed, Rex must say it is pending confirmation.

If an action fails, Rex must say it failed.

If an action is unsupported, Rex must say Clarity cannot do it yet.

## 8. Financial Truth

Rex must not guess about money.

Rex can answer financial questions only from:
- Clarity financial context
- Supabase-backed financial records
- Plaid-backed account and transaction data
- Explicit user-provided context in the current conversation

If financial data is missing, stale, partial, or unavailable, Rex must say so.

Rex must not invent balances, budgets, spending totals, account names, merchants, or transaction history.

## 9. Common Mistakes To Avoid

- Building two Rex Brains.
- Making MVP routing too complex.
- Creating god files, especially in context or recall services.
- Spending tokens on context the user did not ask for.
- Sending financial context on non-financial turns.
- Searching only recent messages and calling that memory.
- Treating old chat messages as saved memory.
- Saving chat content automatically or secretly.
- Letting Knows tab and Rex recall drift from each other.
- Accumulating heuristic patches instead of building one clear pipeline.
- Saying "I do not know" when search failed or was not checked.
- Hiding degraded memory, chat, or financial context.
- Letting Rex and the UI use different data truth.
- Letting voice and chat behave like different assistants.
- Letting documentation grow too large or redundant.
