# Assistant response style + finance access — implementation plan

**Status:** Phases A–C shipped; Phases D–E planned  
**Session context:** Raw Grok path is working well (paycheck advice, dashboard links, real insights). Replies are often too long; finance math can drift when Plaid sync is stale or balances include fees/interest not reflected in the snapshot.

**Canon:** Product rules stay in `docs/CLARITY_RULES.md` and `docs/PROJECT_STRUCTURE.md`. This file is an **execution tracker only** (`docs/archive/`).

---

## 1. Why one file (not many)

Use **this single plan** for the whole initiative. The work shares one settings surface, one assistant pipeline, and one financial context path.

Split into separate archive docs **only if** a phase grows past ~400 lines or a different owner ships it independently (e.g. finance writes vs mobile UI-only).

| Approach | When |
| --- | --- |
| **One file (recommended)** | Same team, shared Assistant tab + `assistant_settings` + finance context |
| Multiple files | Separate epics with independent release trains |

---

## 2. Product goals

### Keep (already good)

- Dashboard deep links from chat (`DashboardInsightAnchor` on assistant bubbles)
- Actionable paycheck guidance (pay credit cards first, budget-aware splits)
- Honest stale-data disclaimers when Plaid sync is old
- Companion settings sheet in Assistant tab (gear / tune icon)

### Improve

| Problem | Direction |
| --- | --- |
| Long markdown essays (`###`, numbered plans) on every turn | **Response style** setting + shorter default prompt rules |
| User cannot skim long replies in chat | **Show more** collapse on assistant bubbles |
| “No breakdown” for merchants/categories | Smarter **transaction selection** in financial context |
| Cannot recategorize or edit budgets via Rex | Productize existing **`clarity_action`** write path |
| Credit totals slightly off (~$850 vs ~$900) | **Truth + stale sync UX** — use snapshot numbers exactly; say when fees/interest may have moved balances |

### Known accuracy note (not a wiring bug)

When sync is ~60h stale, Rex uses the **last snapshot**. Payoff math that assumes “pay $400 toward $511” or “~$850 combined” can miss recent charges, fees, and interest. Fix is:

1. Lead with **exact balances from context** (never round for convenience)
2. One-line stale warning (already partly there) — shorten in Concise mode
3. Optional: “Refresh accounts” action when `freshness.state == stale`

---

## 3. User-facing settings (extend companion sheet)

Add to the existing **Companion settings** bottom sheet (`assistant_proposal_settings_sheet.dart`), same `profiles.assistant_settings` JSON.

### 3.1 Response style (new)

| Mode | Default | Behavior |
| --- | --- | --- |
| **concise** | Recommended for voice-first | Short answer first (2–4 sentences). No `###` headers. One short list max. End with “Want the full breakdown?” when useful. |
| **balanced** | **Default for new users** | Short answer + one structured section if needed. |
| **detailed** | Opt-in | Current behavior — full plans, numbered steps, markdown OK. |

**Per-turn override:** If user says “be detailed”, “full breakdown”, “walk me through it” → treat as **detailed** for that turn only (intent phrase match in orchestrator or mobile flag on request).

**Voice:** Same setting; voice channel may apply **one notch shorter** than chat (e.g. balanced → concise rules) without a separate UI toggle in v1.

### 3.2 JSON shape (extend existing)

```json
{
  "auto_proposals_mode": "off" | "text" | "card",
  "auto_proposals_threads": true,
  "auto_proposals_goals": true,
  "auto_proposals_memory": true,
  "response_style": "concise" | "balanced" | "detailed"
}
```

Default `response_style`: **`balanced`**.

### 3.3 Finance assistant controls (Phase D — optional toggle)

Optional v1.1 toggle (default **on**):

- **Allow Rex to edit transactions and budgets** — when off, Rex may advise but must not emit mutating `clarity_action` blocks.

Confirm cards remain **always required** for mutating actions (CLARITY_RULES truth rule).

---

## 4. Show more (chat UI)

Collapse long **assistant** bubbles; user expands when they want depth. Works with Response style — even Detailed mode benefits on small screens.

### Behavior

- Measure rendered height (or character/line heuristic) after markdown layout
- If over threshold (~6–8 lines or ~420px), show truncated preview + **Show more**
- Expanded state: full text + **Show less**
- User messages: never collapse
- Streaming: expand automatically while streaming; apply collapse only after stream completes
- Voice interim text: same rules when shown in chat transcript

### Files (mobile)

| File | Change |
| --- | --- |
| `chat_message_bubble.dart` | Wrap assistant body in expandable widget |
| New `chat_message_expandable_body.dart` (~80–120 lines) | Threshold, animation, l10n strings |
| `app_l10n*.arb` | `chatShowMore`, `chatShowLess` |

No backend change required.

---

## 5. Backend: response style wiring

### 5.1 Settings module

| Module | Change |
| --- | --- |
| `assistant_proposal_settings.py` | Add `response_style` field + parser; consider rename to `assistant_companion_settings.py` only if file stays under 400 lines |
| `assistant_settings_repository.py` | Unchanged shape — reads full JSON |
| `chat_turn_context.py` | Pass `response_style` on `ChatTurnContext` (extend dataclass or companion settings object) |

### 5.2 Prompt rules (simple, not “super AI tuning”)

New module: `prompt_response_style.py` (~40–80 lines) with three static rule blocks injected in `prompt_service._system_sections` **after** locale, **before** financial context.

Example intent (not final copy):

- **concise:** “Default to brevity. No markdown headings. State the recommendation in the first sentence.”
- **balanced:** “Keep the opening answer short; add one short structured section only when it helps.”
- **detailed:** “You may use headings and numbered steps when the user needs a full plan.”

Also inject existing `CLARITY_KNOWLEDGE_LANGUAGE_PROMPT` here (saved memory vs chat history) — small win from prior audit.

### 5.3 Token caps (hard backstop)

Map style → `max_response_tokens` in `chat_turn_orchestrator.py`:

| Style | Suggested max_tokens |
| --- | ---: |
| concise | 400–500 |
| balanced | 900–1100 |
| detailed | 1800–2200 |

Pass through voice streaming path unchanged (`stream_message` already accepts `max_response_tokens`).

### 5.4 Tests

- `test_assistant_proposal_settings.py` — parse `response_style`
- `test_prompt_service.py` — system prompt contains style section
- `test_chat_service_assistant.py` — max_tokens set per style

---

## 6. Finance read access (Phase C)

**Goal:** Rex cites real transaction descriptions and merchant names; category questions (“Code AI tools”, subscriptions) use matching rows, not only budget aggregates.

### Current state

- Mobile builds `clarity_unified_financial_context_v1` with descriptions when finance intent fires
- Cap: **120 rows** (`kMaxRexTransactionContextRows`)
- Prompt cap: **14k chars** (`MAX_FINANCIAL_CONTEXT_CHARACTERS`) may truncate transaction list before descriptions
- `transaction_slices` give aggregates + small samples — good for overview, weak for “average spend on X”

### 6.1 Intent-aware transaction selection (mobile)

Extend `rex_financial_transaction_policy.dart` + `assistant_financial_context_builder.dart`:

1. Parse finance message for **merchant**, **category name**, **budget name** (reuse finance intent patterns where possible)
2. **Reserve rows:** matched transactions first, then recent fill to 120
3. Add **`matched_transactions`** block in context JSON when filter applies
4. Pre-compute **`category_spend_this_month`** (top merchants per category) — cheap, high value for subscription/code-tool questions

### 6.2 Prompt prioritization (backend)

In `prompt_financial_context.py`:

- Emit **matched_transactions** and **category_spend** before full account dumps
- Reserve ~40% of char budget for transaction rows when `integration.transaction_detail_mode != unavailable`
- When truncating, drop lowest-priority sections first (duplicate account metadata, not matched txs)

### 6.3 Stale sync UX

When `freshness.state == stale`:

- Concise mode: one short line + exact snapshot balances
- Offer dashboard / accounts refresh link (reuse existing dashboard anchor pattern)
- Do **not** invent payoff amounts — quote `current_balance` from account rows only

### 6.4 Acceptance

- “What did I spend on Cursor / OpenAI this month?” → cites transactions with descriptions
- “Average on Code AI tools?” → number from included rows or category_spend block; if partial, say so in one sentence
- Paycheck advice uses **exact** credit card balances from context; if stale, says snapshot may be low/high

---

## 7. Finance write access (Phase D)

**Goal:** User can recategorize transactions and create/edit budgets through Rex with confirm cards.

### Already built

- `ClarityControlService`: `update_transaction`, `bulk_update_transaction_category`, `create_budget`, `update_budget`, …
- Mobile: `ClarityActionCardsStrip`, `executeClarityAction`, `notifyDataChanged()`
- Context advertises `available_controls`

### Gaps

- LLM rarely emits ` ```clarity_action``` ` JSON blocks in practice
- No dedicated finance confirm card copy polish
- Truth guards for “I updated your budget” without execution result

### 7.1 Prompt playbook

Extend financial context header in `prompt_financial_context.py`:

- When user asks to **recategorize**, **rename category**, **create/change budget** → must output fenced `clarity_action` with `confirmation_text` and `risk_level`
- Never claim applied until execution succeeds (align with `action_truth_policy.py`)

### 7.2 Mobile UX

- Ensure finance actions render in `ClarityActionCardsStrip` with clear labels
- After apply: refresh financial read model + short assistant line from formatter (already partially in `chat_controller_actions.dart`)

### 7.3 Truth

- Extend `action_truth_policy.py` / `chat_response_truth.py` for finance success claims when no applied `clarity_action` result

### 7.4 Acceptance

- “Move yesterday’s OpenAI charge to Code AI Tools” → confirm card → category updated in Transactions
- “Set Code AI Tools budget to $250/month” → confirm card → visible in Budgets tab
- Rex never says “done” if user dismissed the card

---

## 8. Phases and checklists

### Phase A — Response style (1 session) **P0**

- [x] Extend `AssistantProposalSettings` (Dart + Python) with `response_style`
- [x] Backend: load on turn; inject `prompt_response_style` section
- [x] Map style → `max_response_tokens` in orchestrator (chat + voice stream)
- [x] UI: segmented control in companion settings sheet
- [x] Per-turn “be detailed” override
- [x] Tests for parse + prompt + tokens

### Phase B — Show more (0.5–1 session) **P0**

- [x] `chat_message_expandable_body.dart`
- [x] Wire into `chat_message_bubble.dart` (assistant only, post-stream)
- [x] L10n strings
- [x] Widget test: long message collapses; tap expands

### Phase C — Finance read (1–2 sessions) **P1**

- [x] Intent-aware transaction selection + `category_spend_this_month`
- [x] Prompt prioritization for matched rows
- [x] Stale sync: exact balances, shorter disclaimer in concise mode
- [x] Tests: context builder selection; prompt includes matched txs

### Phase D — Finance write (1–2 sessions) **P2**

- [ ] Financial action prompt playbook
- [ ] Confirm card copy for recategorize / budget CRUD
- [ ] Truth guards for finance success claims
- [ ] E2E tests: propose → confirm → Supabase row updated (mock or integration)

### Phase E — Polish (0.5 session) **P3**

- [ ] Optional “Allow Rex to edit finances” toggle
- [ ] Dashboard / Accounts refresh anchor when stale
- [ ] Voice: verify concise rules on streaming TTS final text

---

## 9. File touch map (keep under size limits)

| Area | Primary files |
| --- | --- |
| Settings model | `assistant_proposal_settings.py`, `assistant_proposal_settings.dart` |
| Settings UI | `assistant_proposal_settings_sheet.dart` |
| Prompt | `prompt_response_style.py` (new), `prompt_service.py`, `prompt_financial_context.py` |
| Turn | `chat_turn_orchestrator.py`, `chat_turn_context.py` |
| Finance context | `assistant_financial_context_builder.dart`, `rex_financial_transaction_policy.dart` |
| Chat UI | `chat_message_bubble.dart`, `chat_message_expandable_body.dart` (new) |
| Writes | `clarity_control_service.py`, `clarity_action_parser.py`, `action_truth_policy.py` |
| Tests | `test_assistant_proposal_settings.py`, `test_prompt_service.py`, finance context tests |

**Split rule:** If `assistant_financial_context_builder.dart` or `chat_turn_orchestrator.py` need large additions, extract first (PROJECT_STRUCTURE §4).

---

## 10. Out of scope (this plan)

- Backend fetching finance records independently on every turn (mobile remains source of truth for context today)
- Removing markdown rendering entirely (only discourage via style + Show more)
- Auto-sync Plaid from chat (link to Accounts refresh only)
- New docs under `docs/` root (forbidden by canon)

---

## 11. Raw testing checklist (after Phase A+B)

1. Assistant gear → set **Concise** → ask paycheck question → reply ≤ ~6 lines, still recommends paying cards first
2. Same question in **Detailed** → full numbered plan returns
3. Long detailed reply → **Show more** appears; expand shows full text
4. Voice turn with Concise → final spoken text matches short style

After Phase C+D:

5. Ask about specific merchant spend → descriptions appear in answer
6. “Recategorize X to Y” → confirm card → transaction category changes in app

---

## 12. Related shipped work

- Companion proposal settings: `04-companion-proposal-settings-plan.md` (shipped)
- Financial context schema: `assistant_financial_context_builder.dart` (`clarity_unified_financial_context_v1`)
- Clarity actions API: `clarity_control_service.py`, `/clarity/actions`
