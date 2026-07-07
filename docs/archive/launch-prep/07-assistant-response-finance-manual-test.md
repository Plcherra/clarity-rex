# Manual Test Checklist — Assistant Response & Finance (Phases A–E)

Use this after deploying **mobile + rex-api** from `main`. Test on a real account with Plaid-connected accounts and some transaction history.

**Companion settings:** Assistant tab → gear icon (Companion settings sheet).

---

## Prerequisites

- [ ] Backend (`rex-api`) deployed with latest `main`
- [ ] Mobile app built from latest `main`
- [ ] At least one Plaid-linked account with transactions this month
- [ ] Optional: one account with **stale sync** (>24h since last Plaid sync) for stale-data tests

---

## Phase A — Response style

### Settings persistence

- [ ] Open Companion settings → **Reply length** shows Concise / Balanced / Detailed
- [ ] Select **Concise** → leave and reopen sheet → still Concise
- [ ] Select **Detailed** → reopen → still Detailed
- [ ] Kill and relaunch app → setting persists

### Chat behavior

- [ ] With **Concise**: ask “How should I split my paycheck?” → short answer first (2–4 sentences), no `###` headers
- [ ] With **Detailed**: same question → fuller structured answer allowed
- [ ] With **Balanced**: middle length between the two

### Per-turn override

- [ ] With **Concise** selected, ask: “Give me the full breakdown of my spending” (or “be detailed”) → Rex gives a longer answer for that turn only
- [ ] Next message (normal question) → back to concise length

### Voice

- [ ] With **Balanced** profile, use voice for a normal question → reply feels **one notch shorter** than chat (concise-style), not a long essay
- [ ] Voice still understandable and complete on the main point

---

## Phase B — Show more (chat UI)

- [ ] Send a message that triggers a **long assistant reply** (e.g. detailed paycheck plan)
- [ ] Bubble shows truncated preview + **Show more**
- [ ] Tap **Show more** → full text visible + **Show less**
- [ ] Tap **Show less** → collapses again
- [ ] **User messages** are never collapsed
- [ ] While assistant is **streaming**, bubble stays expanded (no collapse mid-stream)
- [ ] After stream completes, long reply collapses if over threshold

---

## Phase C — Finance read access

### Merchant / category questions

- [ ] “What did I spend on Cursor this month?” → cites specific transactions (descriptions/merchants), not “I don’t have a breakdown”
- [ ] “How much on Code AI tools?” → number from category spend or matched rows; if partial data, one honest sentence about limits

### Stale sync honesty

- [ ] With stale Plaid data, ask about credit card payoff or combined balance
- [ ] Rex quotes **exact `current_balance` from snapshot** only
- [ ] Rex does **not** invent interest/fees/payoff totals
- [ ] Rex mentions sync may be stale in one clear line (shorter in Concise mode)

### Dashboard link (fresh data)

- [ ] Finance question with **fresh** sync → assistant bubble shows **View on Dashboard**
- [ ] Tap it → Dashboard tab opens and scrolls to a relevant section (cash flow / spending / budgets)

### Stale sync → Accounts link (Phase E)

- [ ] Finance question with **stale or unknown** sync → bubble shows **Refresh accounts** (not View on Dashboard)
- [ ] Tap it → **Accounts** tab opens (not Dashboard)
- [ ] Use refresh/sync on Accounts → balances update; ask Rex again → answers reflect newer snapshot if sync succeeded

---

## Phase D — Finance write (confirm cards)

### Recategorize transaction

- [ ] “Move yesterday’s OpenAI charge to Code AI Tools” (or similar real transaction)
- [ ] Rex proposes change with a **confirm card** (headline like “Change in Transactions”)
- [ ] Card shows clear confirmation text; **no** “done/saved” before you confirm
- [ ] Tap **Confirm** → transaction category updates in Transactions / account detail
- [ ] Short assistant line after apply (e.g. “Done. I applied the Recategorize transaction change…”)
- [ ] Finance read model refreshed (Rex/dashboard numbers update without manual app restart)

### Create / update budget

- [ ] “Set Code AI Tools budget to $250/month”
- [ ] Confirm card appears (“Change in Budgets”)
- [ ] Confirm → budget visible in **Budgets** tab with correct amount
- [ ] “Change my Food budget to $400” → update card → confirm → Budgets tab reflects change

### Truth — no fake success

- [ ] If Rex ever says “done/updated” **without** a confirm card, response should be corrected to ask for confirmation (not claim applied)
- [ ] Tap **Dismiss** on a finance card → change **not** applied; Rex must not later claim it was saved

### Bulk / rename (if you use these)

- [ ] “Recategorize all Starbucks transactions to Coffee” → confirm card with bulk action
- [ ] Rename category via Rex (if supported in your data) → confirm card → category name updates

---

## Phase E — Finance edits toggle

### Toggle off

- [ ] Companion settings → turn **off** “Allow Rex to edit finances”
- [ ] Ask to recategorize or set a budget
- [ ] Rex **advises** but does **not** show finance confirm cards
- [ ] Rex does **not** claim the change was applied

### Toggle on (default)

- [ ] Turn toggle **on** again
- [ ] Same recategorize/budget request → confirm cards return

### Settings combo

- [ ] **Concise** + finance edits **on** + stale sync → short answer, honest stale note, **Refresh accounts** chip, finance writes still use cards when requested

---

## Regression — Memory & goals (unchanged paths)

- [ ] Save a fact to Knows via Rex → confirm card → appears in Knows
- [ ] Save a goal → confirm card → appears in Goals
- [ ] Open thread offer still respects Auto suggestions mode (Off / Text / Card)
- [ ] “Do you remember …?” recall still searches saved memory + old chats separately labeled

---

## Regression — Voice parity

- [ ] Voice turn for memory save still uses same confirm flow as chat
- [ ] Voice finance question (with financial context attached) gets same honesty rules as chat
- [ ] No duplicate assistant messages or stuck “applying” cards after voice confirm

---

## Known limits (not bugs)

- Payoff math can drift when Plaid sync is days old — Rex should say snapshot only, not estimate fees/interest
- `prompt_financial_context.py` and `chat_turn_orchestrator.py` are oversized — follow-up split recommended, not a test failure
- Finance context only attaches on clearly finance-related turns (not every chat message)

---

## Quick smoke (5 minutes)

1. Set **Concise** → chat → short reply  
2. Long reply → **Show more** works  
3. “What did I spend on [merchant]?” → real transaction names  
4. “Move [charge] to [category]” → confirm → category changes  
5. Stale sync → **Refresh accounts** → Accounts tab  
6. Turn off finance edits → no confirm cards for writes  

---

## Automated tests already run (CI/local reference)

**Backend** (`services/rex-api`):

```bash
python -m pytest tests/test_assistant_response_style.py tests/test_action_truth_policy.py tests/test_clarity_action_proposal_filter.py tests/test_prompt_service.py tests/test_chat_service.py -q
```

**Mobile** (`apps/mobile`):

```bash
flutter test test/assistant_proposal_settings_test.dart test/dashboard_deep_link_navigation_test.dart test/assistant_financial_context_service_test.dart test/chat_message_bubble_test.dart test/chat_message_expandable_body_test.dart
```

Expected: all pass before manual QA.
