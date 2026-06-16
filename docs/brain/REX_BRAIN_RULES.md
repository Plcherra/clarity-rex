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
- Clearly separate saved memory from old chat evidence.
- Never claim a durable action happened unless the backend confirms it.
- Say when memory, old chat search, financial data, or another source is unavailable or degraded.
- Use the same financial data the user sees in Clarity.
- Ask for confirmation before important, risky, destructive, or account-changing actions.

## 3. Memory Truth

Saved memory and old chat history are different.

Saved memory is confirmed Clarity knowledge. It can appear in the "What Clarity Knows" screen and can be edited or deleted by the user.

Old chat evidence is something found in previous conversation messages. Rex can use it, but Rex must label it honestly.

Good:
- "I do not have that saved as memory, but I found an old chat where you said your mom's birthday is June 18."
- "I found this in chat history, not saved memory."
- "I tried to search memory and old chats, but chat search is degraded right now."

Bad:
- "I know your mom's birthday is June 18" when it only came from old chat evidence.
- "I do not know anything about your mom" when chat search failed or was not checked.
- "I saved that" when the backend did not confirm a saved memory record.

## 4. Old Chat Search

Old chat search is part of Rex Brain MVP.

When the user asks what Rex knows, remembers, or talked about before, Rex must search beyond the recent message window.

Old chat search should:
- Search all user chats, including the current conversation.
- Use simple keyword search first.
- Use aliases for common terms, such as mom, mother, mum, and mama.
- Return only the most useful evidence for the current question.
- Avoid flooding the prompt with long chat history.
- Report clearly when search is unavailable or degraded.

Old chat search does not turn every past message into saved memory. Chat history is searchable evidence. Saved memory is curated knowledge.

## 5. Prompt And Token Rules

Rex Brain must protect token usage.

The prompt should include only what is useful for the current turn:
- Short Rex behavior rules
- Relevant saved memory
- Relevant old chat evidence
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
- Spending tokens on context the user did not ask for.
- Searching only recent messages and calling that memory.
- Treating old chat evidence as saved memory.
- Saving every old chat mention as memory.
- Saying "I do not know" when search failed or was not checked.
- Hiding degraded memory, chat, or financial context.
- Letting Rex and the UI use different data truth.
- Letting voice and chat behave like different assistants.
