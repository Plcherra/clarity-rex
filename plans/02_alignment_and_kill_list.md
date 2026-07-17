# 02 — Alignment and kill list

**Status:** Phases A–D complete (2026-07-17). Kill list frozen; proceed to plan 03.  
**Depends on:** [`01_vision_gap_and_token_budget.md`](01_vision_gap_and_token_budget.md) (gate accepted)  
**Next:** [`03_canon_update.md`](03_canon_update.md)

## 1. Purpose

Decide what **keeps**, **parks**, or **dies** before aggressive deletion (plan 04) and rebuild (plan 05). Prefer mismatch removal over living with two brains.

### Platform notes

- **CI scripts / VPS helpers / usage tracking transport** — KEEP (body/ops). Not understanding brains.
- **Staging CD / infra optimization projects** — park; do not block kill list.
- Kill list stays about **assistant understanding**, plus retiring `docs/archive/` (process clutter).

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
| Named social groups | Part of the **person-card net** (same feature family as Connections / Shared history) — see §4 |
| Milestones | In catalog; basic create/update/delete under plans in plan 05 late phase |
| Finance **fetch** insights | `fetch_spend_insight`, `fetch_account_summary` — not always-on FC |

Do not auto-create edges from chat or ops backfill (existing Truth Rule).

## 4. Person-card net vs launch timing

**Person-card net** (one product family):

1. Person cards + rolling state + notes  
2. Connections (edges)  
3. Shared history (multi-person events)  
4. Named social groups (e.g. “college friends”) — same Saved Memory rules: confirm + visible in Knows  

**Launch vs after (locked for these plans):**

| Slice | When |
|-------|------|
| Brain cutover + goals/threads + basic milestones | Plan 05 (core → late phases) |
| Person state + notes | Plan 05 |
| Connections + Shared history Knows UI + capabilities | Plan 05 Phase H — **required for Truth before neighborhood prompts** |
| Named social groups | **Same net, after** Connections + Shared history are visible in Knows (still plan 05 if time; else immediate follow-up — not a forever park) |

Spanish and more languages: ship EN+ES comfort now; expand over time (README) — does not block brain cutover.

## 4b. Still parked / never interim

| Item | Why |
|------|-----|
| Native iOS voice bridge experiments | Must not become second brain |
| Embedding-as-understanding / topic anchors / Smart Thread Overlap | **Fight vision** — kill with detectors |
| Staging / auto-CD / infra resize | Nice after brain ships |

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

### 5.6 Always-on heavy context (base turn bloat)

- Paths that inject large LTM / full finance / full inventory on every turn without a fetch action
- Replace with fetch capabilities in plan 05; strip in plan 04 even if replies get dumber temporarily

### 5.7 Reply length (remove — fights natural Grok)

User-facing **Reply length** (concise / balanced / detailed) injects style instructions and token caps that reshape Grok away from its natural voice.

**Kill / stop shipping:**

- Profile UI for reply length (Companion saves / assistant settings)
- `response_style` on profile + `prompt_response_style.py` injection into system prompt
- `assistant_response_style.py` / `max_response_tokens_for_style` forcing shorter answers for “concise”

**Keep:** Auto Suggestions Off/Text/Card + kind toggles + finance edits. Grok chooses length naturally.

### 5.8 Do not kill (re-stated)

- Durable write apply/propose machinery (including milestone apply paths)
- OpenThreadService CRUD
- Truth guards (may slim patterns later; keep honesty)
- Settings load/store for proposal mode/kinds (not reply length)
- Voice STT + **Google TTS** transport

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

## 7. Flat memory vs person cards — duplicates

- Flat memories allowed for non-person facts.
- Must not conflict with person cards.
- **Never archive** duplicate memories/goals/info as a soft hide — if it is a true duplicate, **delete** it (body discipline).
- Day-to-day person situations → person notes + state updates, not endless flat duplicates.

## 8. Phases

### Phase A — Walk UI vs catalog

- [x] Knows, Goals (incl. milestones UI if any), Finance, Profile settings
- [x] Note reply-length UI for removal
- [x] Update finance mismatches for plan 05 catalog

*(No milestone Knows/Goals UI today. Reply length ships in Companion settings. Finance: no manual create-tx; strip `create_transaction` from assistant `availableControls` in plan 05. Connections/Shared history Knows UI absent — capabilities stay required-later §3.)*

### Phase B — Confirm kill list paths exist

- [x] Grep repo for files in §5; note dependents/tests that will break (expected)
- [x] List body modules that must remain importable after 04 (incl. milestone durable write)

*(All §5 primaries exist. Coupling: `durable_write_*` / `action_truth_policy` import some kill helpers today — rewire or isolate in 04/05, do not delete KEEP body.)*

### Phase C — Social net + milestones signed off

- [x] Milestones in catalog; built late in plan 05 (not parked forever)
- [x] Social groups = person-card net after Connections + Shared history
- [x] No embedding/overlap interim
- [x] Duplicates → delete, not archive

### Phase D — Gate

- [x] Kill list frozen for plan 04 (includes reply length) *(2026-07-17)*
- [x] Proceed to plan 03 (canon **before** delete) *(human go 2026-07-17)*

## 9. Explicit non-goals for 02

- No deletion yet
- No canon edits yet
- No new brain code
