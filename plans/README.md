# Clarity execution plans

These files under `plans/` are the **only** execution plans for the app. Do not add competing plan docs under `docs/` or revive archived trackers. Plans 01–05 are the Grok-brain cutover. Plan 06 is pre-launch work on the same working branch.

## Product one-liner (shipping intent)

Real Plaid sync · Grok-powered Rex · voice-first design  
Personal finance that actually understands you.

Rex only saves what you explicitly confirm. Every durable action is backend-verified — no fake memory, no invented balances, no hidden saves.

Dark-first UI, English + Spanish at launch, smooth voice mode, comfortable mobile experience. More languages later — implemented over time, not blocking the brain cutover.

## Canon hearts (separate)

Product and engineering law live only in:

- [`docs/MASTER_PLAN.md`](../docs/MASTER_PLAN.md)
- [`docs/CLARITY_RULES.md`](../docs/CLARITY_RULES.md)
- [`docs/PROJECT_STRUCTURE.md`](../docs/PROJECT_STRUCTURE.md)

Agents must follow those three plus these plans. Do not invent parallel architecture docs.

## Order (strict)

| # | File | When |
|---|------|------|
| 01 | [`01_vision_gap_and_token_budget.md`](01_vision_gap_and_token_budget.md) | Audit / lock vision — no product code |
| 02 | [`02_alignment_and_kill_list.md`](02_alignment_and_kill_list.md) | Keep / park / kill inventory |
| 03 | [`03_canon_update.md`](03_canon_update.md) | Update the three hearts + docs CI — **before** deletion |
| 04 | [`04_aggressive_deletion.md`](04_aggressive_deletion.md) | Delete misaligned brain/plans — break-OK |
| 05 | [`05_simple_brain_implementation.md`](05_simple_brain_implementation.md) | Rebuild simple Grok brain + body handlers (milestones + social net in later phases) |
| 06 | [`06_pre_launch.md`](06_pre_launch.md) | Pre-launch blocking fixes (leftover + leak, money chips, JWT/realtime, Plaid reconnect, passwords) |

Execute **file by file**, **phase by phase**. Manual tests at each phase gate. Do not skip 03 before 04. Plan 06 does not reopen the kill list.

## Locked architecture

```text
Chat/Voice → Orchestrator
  → tiny system (Truth + Off/Text/Card + capability NAMES)
  → thin state (recent turns + open thread titles if any)
  → Grok (LLM brain) → structured action(s) | just_chat | unsupported
  → fetch capability if needed (finance / person / recall)
  → Auto Suggestions gate → body execute → Truth → reply
  → Voice: Google TTS speaks the reply (not Grok voice)
```

- **Brain** = Grok as **LLM only** (understanding + reasoning). No long persona prompt. Speech = **Google TTS**.
- **Body** = backend feature executors only.
- **Token budget** = **base** turn aims **&lt; ~1k** input. May exceed when tools/fetch/heavy context are requested — situation-dependent, not a hard cap forever.
- **No** regex/overlap/embedding “second brain.” Those die in plan 04.
- **Reply length setting** — **remove** from Profile/UI and backend (`response_style` / `prompt_response_style` / style token caps). Let Grok answer naturally. Tracked in plans 02 §5.7, 04 Phase E, 05 Phase A/B.

## Platform topics (folded in — no extra plans)

| Topic | Need vs nice | Where it lives |
|-------|--------------|----------------|
| **Token / prompt cost** | **Need** (base &lt;1k; fetch may add) | 01 + 05 |
| **Environments (local vs prod)** | **Need (light)** | 03 + 05 deploy |
| **CI** | **Need (keep)** | 03 / 04 red / 05 green |
| **CD / staging / UML suite / VPS resize** | Nice later | After brain ships |

## Out of scope for other folders

- Do not create new planning files under `docs/` (canon root is three files only after plan 03).
- Do not archive old plans — plan 04 **deletes** them.
- Do not implement Smart Thread Overlap / topic anchors / embedding-as-understanding.
- Do not “archive” duplicate user memories/goals — **delete** duplicates (body discipline).
