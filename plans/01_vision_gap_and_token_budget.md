# 01 — Vision, gap, and token budget

**Status:** execution plan (authoring complete). Run phases below before plan 02.  
**Code changes in this plan:** none (read-only audit).

## 1. Locked vision

Clarity’s assistant is **simple**:

| Layer | Role |
|-------|------|
| **Brain** | Grok — understands the user every turn; supplies thinking and personality. No prompt “persona” essay. |
| **Body** | Backend features — the only things that can fetch data or mutate state. |
| **Gate** | Auto Suggestions (Off / Text / Card) + kind toggles — applied **after** Grok’s meaning, not as language detectors. |
| **Honesty** | Truth Rule — never claim saved/updated/sent unless the body applied it this turn. |

### Target pipeline

```text
Chat/Voice → ChatService → Orchestrator
  → tiny system (Truth + Off/Text/Card + capability NAMES)
  → thin state (recent turns + open thread titles if any)
  → Grok thinks → structured action(s) | just_chat | unsupported
  → fetch capability if needed (finance / person / recall)
  → Auto Suggestions gate → body execute → Truth → reply
```

One understanding path. Many capability handlers. No competing heuristic brains.

### What we are not building

- Regex / phrase / overlap / embedding layers that **understand** the user instead of Grok.
- Always-on finance or Knows dumps.
- A second LLM call on the phone before the API.
- Prompt-crafted “Rex personality” beyond Truth + capabilities + thin state.

## 2. Token budget (≤ ~1k default input)

Target **≤ ~1000 tokens** of model input on a normal turn (excluding rare fetch follow-ups).

| Piece | Budget guide | Notes |
|-------|--------------|--------|
| Capability **names** only | ~80–150 | No long descriptions |
| Truth + Off/Text/Card + kind flags | ~150–250 | Stable, short |
| Recent chat window | ~300–500 | Cap turns / chars |
| Open thread titles (≤5) | ~50–100 | Titles only unless fetch |
| **Default total** | **≤ ~1k** | Hard product goal |
| Fetch packs | Extra | Only when an action requests them |

**Fetch-on-demand (not always-on):**

- Finance summary / transactions / account balances
- Full person card + recent notes / shared history
- Chat recall search hits
- Knows / Goals inventory lists

## 3. Slim capability catalog (names only)

Catalog in the system prompt is **identifiers**, not manuals. Body must actually implement each name.

### Memory / people

- `save_memory` / `update_memory` / `delete_knows_item`
- `save_person` / `update_person_state`
- `add_person_note` (related note on a person — part of the person card story)
- `save_connection` / `save_shared_history` (when Knows UI exists — Truth Rule)
- `fetch_person_context`
- `search_chats` / `list_knows_summary`

### Goals / open threads

- `create_goal` / `update_goal` / `delete_goal`
- `create_open_thread` / `update_open_thread` / `delete_open_thread`
- Milestones: **parked** until smoked (see plan 02) — omit from catalog until then

### Finance (must match manual UI)

- `fetch_spend_insight` / `fetch_account_summary`
- `categorize_transaction` / `bulk_categorize`
- `create_category` / `update_category` / `delete_category`
- `create_budget` / `update_budget` / `delete_budget`
- Plaid connect/disconnect and CSV import as body capabilities that match real app flows
- **No** `create_transaction` if users cannot create txs outside Plaid/CSV import

### Meta

- `just_chat`
- `unsupported` (email, SMS, external world, …)

## 4. Person memory model (light state, full insight)

Problem: hours of talk about a co-worker, then “what happened today” — without stuffing transcripts into every turn.

| Store | Content | When loaded |
|-------|---------|-------------|
| **Person card state** | Short confirmed summary of who they are + current relational status | `fetch_person_context` or mention-triggered fetch |
| **Person notes / shared history** | Discrete confirmed moments (light bullets) | Same fetch, capped |
| **Chat history** | Full detail via `search_chats` | When user asks or state is insufficient |
| **Flat memory** | Non-person facts only; must not duplicate/conflict with person cards | As today, with discipline |

After many events, Grok **proposes** updating `update_person_state` (+ optional note). User confirms. Next “today” turn uses **state + few notes**, not three hours of tokens.

Connections / Shared history remain Saved Memory (Knows), confirm-visible, before prompt neighborhood (existing Truth Rule).

## 5. Gap scorecard (today vs vision)

| Vision | Today (approx.) | Gap |
|--------|-----------------|-----|
| Grok understands every turn | Often skipped by short-circuits | **Large** |
| Backend only executes | Backend also detects with regex | **Large** |
| Auto Suggestions after meaning | Tangled into detectors | **Medium** |
| ≤1k default input | Heavy context / FC / memory dumps common | **Medium–Large** |
| Slim capability names | Implicit + large prompts | **Medium** |
| Person rolling state | Partial person cards; social web incomplete | **Large** |
| Finance = manual UI + fetch insights | Clarity actions exist; catalog may over-offer | **Medium** |
| Single pipeline | ~10 heuristic short-circuits + LLM fallback | **Large** |

**Reusable body (keep for plan 05):** durable write propose/apply, confirm cards, open-thread service, finance control service, Truth modules, proposal settings, chat/voice entry.

**Competing brains (kill in plan 04):** intent routers, open-thread offer/overlap eligibility, memory/goal/plan short-circuit detectors, short-circuit router as understanding layer.

## 6. Current pipeline (audit reference)

```text
Chat/Voice → ChatService → ChatTurnOrchestrator
  1. Heuristic intent (RexIntentRouter)
  2. Load context (incl. recall if heuristic says so)
  3. SHORT-CIRCUITS (first hit wins — often NO Grok):
       durable confirm → open_thread → conversational_plan
       → plan dates → memory delete → goal command
       → memory turn → pending yes/no → finance guard
  4. Else Grok reply
  5. Parse finance actions + truth rewrite
```

Key files: `chat_turn_orchestrator.py`, `chat_turn_orchestrator_short_circuit.py`, `simple_rex_brain.py`, `rex_intent_*.py`, `open_thread_turn_*.py`, `open_thread_eligibility.py`, `open_thread_overlap.py`, `memory_turn_*.py`, `conversational_plan_service.py`, `goal_command_service.py`, `durable_write_*.py`, `chat_response_truth.py`.

## 7. Phases (plan 01 only — read-only)

### Phase A — Confirm vision with stakeholders

- [ ] Re-read this file + [`plans/README.md`](README.md)
- [ ] Agree: Grok brain, body execute, ≤1k, fetch-on-demand, no persona prompt
- [ ] Agree: no embedding/overlap interim work

### Phase B — Audit current turn cost (manual)

- [ ] Capture 2–3 production/dev turns (Off, Text, finance ask)
- [ ] Note roughly what is stuffed into the prompt (threads, LTM, FC, recall)
- [ ] Record whether short-circuit skipped Grok

### Phase C — Catalog draft freeze

- [ ] Walk mobile UI: list every mutate/fetch user can do
- [ ] Cross-check against section 3; mark mismatches for plan 02
- [ ] Do **not** add capabilities that UI cannot do

### Phase D — Gate

- [ ] Gap scorecard accepted
- [ ] Proceed to plan 02

## 8. Explicit non-goals for 01

- No code deletion or feature implementation
- No canon file edits (plan 03)
- No deploy
