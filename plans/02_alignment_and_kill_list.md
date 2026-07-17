# 02 — Alignment and kill list

**Status:** execution plan. Run after plan 01 gate.  
**Depends on:** [`01_vision_gap_and_token_budget.md`](01_vision_gap_and_token_budget.md)  
**Next:** [`03_canon_update.md`](03_canon_update.md)

## 1. Purpose

Decide what **keeps**, **parks**, or **dies** before aggressive deletion (plan 04) and rebuild (plan 05). Prefer mismatch removal over living with two brains.

## 2. Aligns with vision — KEEP (body / policy)

These are executors, transport, or honesty — not competing understanding brains.

| Area | Modules / surfaces | Role after redesign |
|------|--------------------|---------------------|
| Chat / voice entry | `chat_service.py`, routes chat/voice/stream | Same entry → thin orchestrator |
| Durable write pipeline | `durable_write_service.py`, `durable_write_proposal.py`, `durable_write_applier.py`, `durable_write_builders.py`, `durable_write_pending.py` | Body for Knows / Goals / threads / delete |
| Confirm UX | Mobile `write_proposals` / `write_confirmation`; voice same | Unchanged product rule |
| Open thread **storage** | `open_thread_service.py`, repository, REST `/open-threads` | Body only; no offer detectors |
| Memory / entity / plan **services** | entity, memory write, plans REST | Body CRUD |
| Finance control body | `ClarityControlService`, `POST /clarity/actions`, parser (as executor of Grok actions) | Body; catalog must match UI |
| Proposal settings | `assistant_proposal_settings.py` | Gate **after** Grok |
| Truth | `chat_response_truth.py`, `action_truth_policy.py`, related | Always last |
| Recall **engine** | `chat_recall_service.py`, search ranking/repo | Capability `search_chats` |
| Prompt assembly (rewired) | `prompt_service.py`, thin context builders | Names + thin state + fetch packs |
| Grok I/O | AI service / generate-stream used by brain | Brain transport |
| File size / module split rules | PROJECT_STRUCTURE limits | Still apply |

## 3. Aligns later — REQUIRED in plan 05 (canon)

| Capability | Notes |
|------------|--------|
| Connections (`save_connection`) | Confirmed edges; Knows UI before prompt neighborhood |
| Shared history (`save_shared_history`) | Multi-person events; same confirm path chat+voice |
| Person rolling **state** (`update_person_state`) | Light summary on person card; notes under person |
| Finance **fetch** insights | `fetch_spend_insight`, `fetch_account_summary` — not always-on FC |

Do not auto-create edges from chat or ops backfill (existing Truth Rule).

## 4. Park — do not block redesign; omit from catalog until smoked

| Item | Why parked |
|------|------------|
| Milestones as primary Goals path | Not fully tested; plans/threads first |
| Bulk plan target-date UX polish | Keep executor if cheap; do not build heuristic short-circuit |
| Named social groups (“college friends”) | MASTER_PLAN “later” |
| Native iOS voice bridge experiments | Must not become second brain |
| Spanish / i18n launch expansions | Separate from brain cutover |
| Embedding-as-understanding / topic anchors / Smart Thread Overlap | **Fight vision** — never interim; kill with detectors |

## 5. Misaligns — KILL LIST (plan 04 deletes)

Understanding stolen from Grok. Delete even if chat breaks until plan 05.

### 5.1 Planning docs (delete, do not archive)

- Entire [`docs/archive/`](../docs/archive/) tree
- Any other repo plan trackers that compete with `plans/01–05` (except the three canon hearts and `plans/`)

### 5.2 Intent / classify as understanding

- `rex_intent_router.py` (as turn authority)
- `rex_intent_patterns.py`
- `rex_intent_memory.py` / `rex_intent_finance.py` (heuristic classify path)
- `SimpleRexBrain.classify` dependency on the above for short-circuit routing

### 5.3 Short-circuit understanding router

- `chat_turn_orchestrator_short_circuit.py` — replace with capability dispatch in 05; delete understanding branches in 04
- Pre-Grok first-hit-wins offer paths that skip Grok

### 5.4 Open-thread heuristic brain

- `open_thread_eligibility.py` (offer/habit/overlap eligibility as understanding)
- `open_thread_overlap.py` / topic-anchor / embedding match helpers
- `open_thread_turn_update.py` (detector-driven update offers)
- Offer/consent **detection** inside `open_thread_turn_service.py` (keep only if temporarily wired through Grok actions in 05; prefer gut in 04)

### 5.5 Memory / goal / plan heuristic brains

- `memory_turn_service.py` / `memory_turn_handle.py` short-circuit path
- `memory_intent_service.py` and `memory_intent_*.py` regex parsers used to steal turns
- `conversational_plan_service.py` as pre-Grok offer brain
- `goal_command_service.py` phrase-driven short-circuit (list/commands that bypass Grok)
- `plan_target_date_update_service.py` short-circuit detector
- `memory_delete_turn_service.py` short-circuit detector
- `conversational_plan_detection.py` and similar “looks like plan” helpers used before Grok

### 5.6 Always-on heavy context that violates ≤1k

- Paths that inject large LTM / full finance / full inventory on every turn without a fetch action
- Replace with fetch capabilities in plan 05; strip in plan 04 even if replies get dumber temporarily

### 5.7 Do not kill (re-stated)

- Durable write apply/propose machinery
- OpenThreadService CRUD
- Truth guards (may slim patterns later; keep honesty)
- Settings load/store
- Voice STT/TTS transport

## 6. Finance catalog alignment rule

Rex may only offer finance actions the **user can do manually** in the app:

| User can | Catalog |
|----------|---------|
| Categorize / edit / delete transactions (as UI allows) | Yes |
| Category CRUD | Yes |
| Budget create/set/update/delete | Yes |
| Plaid connect / disconnect / fix | Yes (as real flows) |
| CSV import | Yes (start/guide body) |
| Create transaction from thin air when only Plaid/CSV creates them | **No** |
| Spend / account summary questions | Yes via **fetch** capabilities |

## 7. Flat memory vs person cards

- Flat memories allowed for non-person facts.
- Must not conflict with person cards (discipline / merge / archive duplicates — body rules, not regex understanding).
- Day-to-day person situations → person notes + state updates, not endless flat duplicates.

## 8. Phases

### Phase A — Walk UI vs catalog

- [ ] Knows, Goals, Finance, Profile settings: checklist of real actions
- [ ] Update section 6 mismatches for plan 05 catalog

### Phase B — Confirm kill list paths exist

- [ ] Grep repo for files in §5; note dependents/tests that will break (expected)
- [ ] List body modules that must remain importable after 04

### Phase C — Park list signed off

- [ ] Milestones parked
- [ ] No embedding/overlap interim

### Phase D — Gate

- [ ] Kill list frozen for plan 04
- [ ] Proceed to plan 03 (canon **before** delete)

## 9. Explicit non-goals for 02

- No deletion yet
- No canon edits yet
- No new brain code
