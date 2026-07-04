# CLARITY_RULES.md

**Canon:** all behavioral rules for Clarity — product values, assistant behavior, memory, Open Threads, recall, voice, action truth, and financial truth.

Product vision: [`MASTER_PLAN.md`](MASTER_PLAN.md). Code paths and wiring: [`PROJECT_STRUCTURE.md`](PROJECT_STRUCTURE.md).

## 1. Purpose and Product Identity

Clarity is a personal finance app with a companion assistant built in. It connects to bank accounts, tracks spending, helps with budgets, remembers what you choose to save, and gives honest advice through chat and voice.

The core promise: everything important about your money and goals lives in one place, and your assistant (Rex) actually understands all of it.

**Clarity is the product. Rex is the assistant personality inside Clarity — not a separate app, not a separate system, not a second brain.**

The assistant should feel like part of Clarity. Chat and voice are input/output modes of the same assistant, with the same memory rules, action rules, and truth policy.

For MVP, keep the assistant pipeline simple. Grok provides most of the intelligence. Clarity provides the data truth. The backend loads the right context, enforces honest labeling, and confirms durable actions before success language is used.

## 2. Core Values

- Build for trust first.
- Keep the app clear, calm, and useful every day.
- Prefer simple, maintainable behavior over clever heuristics.
- Never fake success. If something was not saved, synced, deleted, or updated, do not claim it was.
- The UI and assistant must always operate from the same data truth.
- Keep financial data private and user-scoped.
- Use deterministic rules for obvious financial logic. Use AI only where it truly adds value.
- Plaid is the primary source of financial data. CSV/manual import is a fallback.
- When adding behavior, ask whether it makes the system simpler or more complex.

## 3. Context Layers

The assistant operates with distinct context layers. It must label each layer honestly and never treat one as another.

| Layer | What it is | Where it shows | Write rule |
| --- | --- | --- | --- |
| **Saved memory** | Durable, categorized knowledge | Knows tab | Confirm card or Knows form; backend-confirmed |
| **Open Threads** | Opt-in companion continuity | Goals tab → Open Threads | User consent + backend-confirmed; not memory |
| **Chat history** | Searchable past messages | Chats tab; recall prompts | Read-only; never auto-promoted |
| **Goals (`plans`)** | Big clear objectives | Goals tab → Goals section | Confirm card or Goals form; backend-confirmed |

**Legacy:** Commitments were retired (July 2026). Open Threads replace companion follow-up UX. Legacy commitment data may exist for migration only — not product surface.

## 4. Memory Truth

Only things the user explicitly saves with backend confirmation become durable memory.

Saved memories must be organized into clear categories: People, Events, Places, Goals, Preferences, Facts, and other useful Clarity memory groups. The direction is entity-first saved knowledge, especially People. Flat memories remain a backward-compatible fallback.

Only properly saved and categorized memories appear on the Knows page ("What Clarity Knows"). If the assistant saves anything as memory, it is durable memory. There is no hidden save path.

There must be no automatic or hidden saving of chat content into memory.

Old chat messages are not saved memory. The assistant must not treat old chat messages as saved memory or confirmed Clarity knowledge unless the user explicitly asks to save them.

The assistant can search chats when the user asks recall questions, but search results remain chat history unless the user explicitly saves something as memory.

**Good:**
- "I do not have that saved as memory, but I found a chat message where you said your mom's birthday is June 18."
- "I found this by searching chats. It is not saved memory."
- "I can save that as memory if you want."
- "I tried to search memory and old chats, but chat search is degraded right now."

**Bad:**
- "I know your mom's birthday is June 18" when it only came from chat search.
- "I do not know anything about your mom" when chat search failed or was not checked.
- "I saved that" when the backend did not confirm a saved memory record.
- Saving chat content automatically without a clear save action.

Saved knowledge in Knows and assistant recall must share one unified source of truth. Memory must prefer entity-based organization over many flat items.

## 5. Open Threads

Open Threads are opt-in companion context. They are **not** saved memory and **not** chat history.

They let the assistant follow up on personally meaningful or ongoing topics without turning chat history into saved memory and without requiring a full Goal or Knows record. Open Threads are topic-agnostic and user-scoped — they must work for any user and any life topic, never hard-coded subjects or smoke-test phrases.

**Product placement:**

| Surface | What it shows |
| --- | --- |
| Knows tab | Saved memory only |
| Goals tab — Goals section | Big objectives (`plans`) |
| Goals tab — Open Threads section | Active open threads (max 5) |
| Chat / voice | Assistant may reference active threads and ask light follow-ups |

**Non-negotiable rules:**
- Maximum **5 active** open threads per user.
- Thread creation requires explicit user consent and backend confirmation.
- The assistant may offer once to track an ongoing or personally meaningful topic; if declined, do not nag in the same conversation.
- Open Threads appear in the Goals tab, not in Knows.
- Never auto-create threads from chat content.
- Detection uses generic signals (ongoing, personal, unresolved, user-stated importance) — never hard-coded topics.
- Prompt and UI must label threads as opt-in companion context, not saved memory.
- Do not run a parallel commitment-style follow-up system alongside Open Threads.

**When the assistant may offer to track a thread** (generic eligibility, not topic lists):
- User describes something personally meaningful, ongoing, or likely to continue.
- User expresses intent to try, return, work on, or figure something out.
- Topic is not already an active thread, active Goal, or saved memory duplicate.

**Do not offer when:**
- Message is casual/social only.
- Topic is a one-off factual question with no continuity need.
- User is asking for recall/search — use chat search instead.
- User already declined tracking in the current conversation.
- Active thread cap (5) is reached — offer to close or replace an existing thread instead.

**Follow-up behavior:**
- Reference at most one thread naturally per turn when it fits.
- Ask a light follow-up question when appropriate — not mandatory every turn.
- If the user changes subject, drop it.
- Follow-ups must be skippable.

**Good:**
- "You asked me to keep track of this — how did it go?"
- "I don't have that saved as memory, but you asked me to follow up on this thread."
- "Want me to keep track of this and check in later?"

**Bad:**
- Creating a thread because the user mentioned one specific topic once.
- Treating a thread as saved memory or Knows knowledge.
- Saying "I saved that" when only a thread was created.

## 6. Chat Recall

Recall is not a second AI inside Clarity. Clarity retrieves truthful, user-scoped context. Grok reasons and answers from that context.

When the user asks what the assistant remembers, what they said, what was talked about before, or asks "do you remember…", the assistant must search beyond the recent message window — saved memory and old chats.

**Recall questions include:**
- "Do you remember…"
- "What did I say about…"
- "Search chats about…"
- "Do you know anything about my mom?"

**Old chat search should:**
- Search all user chats, including the current conversation.
- Use simple keyword search first.
- Use aliases as part of a reusable taxonomy (e.g. mom, mother, mum, mama).
- Return only the most useful chat matches for the current question.
- Avoid flooding the prompt with long chat history.
- Report clearly when search is unavailable or degraded.

Old chat search does not turn past messages into memory. Chat history is searchable history. Saved memory is explicit, durable, categorized knowledge.

### Recall guardrails

**Allowed recall fixes:**
- Lightweight recall intent detection.
- Reusable query expansion and aliases.
- User-scoped indexed chat search.
- Conversation-level excerpts with nearby turns.
- Clear source status: found, empty, partial, degraded, or unavailable.
- Prompt labels that separate saved memory from chat history.
- Generic ranking improvements based on information density, source quality, conversation coverage, and query/result relevance.
- Tests that prove the same mechanism works on arbitrary names, dates, places, devices, payments, goals, and exact phrases.

**Not allowed:**
- Topic-specific recall branches (mom-only, PC-only, game-only, payroll-only, etc.).
- Smoke-test keyword patches or hardcoded ranking triggers for one observed phrase, person, device, date, amount, or relationship.
- Adding aliases only because one manual test failed — aliases must be part of a reusable taxonomy.
- Fixes that only pass one example but fail an unrelated equivalent.
- Backend-composed answers that bypass Grok reasoning.
- A second recall planner, memory system, or router for MVP.
- Claims that search ran, found nothing, or saved memory without backend evidence.

**Before changing recall code, name the generic failure class:**
- Query too broad or too narrow.
- Recent noisy chats outrank older factual chats.
- Excerpts drop nearby factual details.
- Search source is empty, filtered, partial, degraded, or unavailable.
- Prompt/truth labeling misstates what was retrieved.

Then fix that generic class. If implementation mentions a specific smoke topic, it must be only test data or a member of a broader taxonomy — never the reason the code works.

### Source labeling

| Source | Labeling rule |
| --- | --- |
| Saved flat memory | Saved memory / Clarity knows |
| Structured entity/person/rule/plan | Saved structured memory / Knows |
| Old chat result | Chat history / found in a past conversation |
| Open Thread | Open thread / user opted in to follow-up; **not** saved memory |
| Goal (`plan`) | Goal |
| Failed or unavailable source | Degraded or unavailable; do not say nothing was found |

A failed source is not proof the user never said something.

## 7. Prompt and Token Discipline

Protect token usage. The prompt should include only what is useful for the current turn:

- Short assistant behavior rules
- Relevant saved memory
- Active open threads on substantive turns (labeled; not saved memory)
- Relevant chat search results when the user asks for recall
- Relevant financial context (**finance turns only**)
- Recent conversation context
- The user's latest message

Do not load broad memory, long chat history, or large structured context unless the user asks for it or the intent clearly needs it. If context is too large, prefer the most relevant and recent items.

Financial context must only be included when the user intent is clearly financial.

## 8. Voice

Voice and chat use the same assistant rules, memory rules, action rules, context rules, and truth policy. Voice is an input/output mode, not a separate assistant.

Voice may add transcript caution, but it must not use a separate memory system, action system, or truth policy.

If a voice transcript is unclear, the assistant should ask for clarification before saving a fact.

Local/on-device speech recognition may be used only for interim UX. It must not save memory, answer, or perform actions outside the backend assistant path.

## 9. Action Truth

The assistant must never fake completed actions.

Durable actions require backend confirmation before success language is used.

**Durable actions include:**
- Saving, updating, or deleting memory
- Creating, updating, or deleting goals (`plans`)
- Creating, updating, pausing, or closing open threads (after user consent)
- Changing transactions, accounts, categories, or budgets
- Sending reminders, notifications, messages, or external actions
- Any financial or account-changing operation

If an action is only proposed, the assistant must say it is pending confirmation. If an action fails, say it failed. If unsupported, say Clarity cannot do it yet.

The assistant must distinguish clearly between insights, suggestions, and completed actions.

## 10. Financial Truth

The assistant must not guess about money.

It can answer financial questions only from:
- Clarity financial context
- Supabase-backed financial records
- Plaid-backed account and transaction data
- Explicit user-provided context in the current conversation

If financial data is missing, stale, partial, or unavailable, the assistant must say so.

The assistant must not invent balances, budgets, spending totals, account names, merchants, or transaction history.

Financial read models are the single source of truth for Dashboard, Budgets, Transactions, and the assistant. Budgets must reflect the same truth shown in the dashboard.

**Finance behavior rules:**
- Backend owns all Plaid logic and token management.
- Persist Plaid data before using it in dashboards, budgets, or assistant context.
- All features must use the same normalized transaction and account models.
- Assistant financial context is sent only on clearly financial turns.
- Unavailable/degraded/partial financial context is unreliable — say data is unavailable rather than guessing.
- Confirmed financial actions through the assistant must follow the same validation and refresh rules as native UI writes.

## 11. Assistant Tone

- Honest, calm, and supportive — never shame the user.
- Ask for confirmation before important, risky, destructive, or account-changing actions.
- Say when data is missing, stale, or degraded.
- Must feel like part of Clarity, not a separate app.

## 12. Common Mistakes to Avoid

- Treating the assistant or Rex as a separate app or parallel system
- Building two assistant pipelines (one for chat, one for voice)
- Letting the assistant and the UI use different data
- Claiming success before backend confirmation
- Making routing too complex or adding topic-specific recall/thread branches
- Searching only recent messages and calling that memory
- Treating old chat messages as saved memory
- Saving chat content automatically or secretly
- Letting Knows tab and assistant recall drift from each other
- Accumulating heuristic patches instead of one clear retrieval pipeline
- Saying "I do not know" when search failed or was not checked
- Hiding degraded memory, chat, or financial context
- Sending financial context on non-financial turns
- Spending tokens on context the user did not ask for
- Treating open threads as saved memory or Knows knowledge
- Auto-creating threads from chat mentions
- Reintroducing Commitments or parallel follow-up systems
- Creating god files in context, recall, or prompt code
- Putting Plaid logic in the wrong place
- Hiding errors from the user
- Using vague file/function names
- Letting documentation grow redundant — canon is three files only

## 13. How to Use This File

When working on any task, keep these rules in mind. Start important conversations by referencing relevant sections. Technical wiring lives in [`PROJECT_STRUCTURE.md`](PROJECT_STRUCTURE.md).
