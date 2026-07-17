# Clarity execution plans

These five files are the **only** execution plans for the app. Do not add competing plan docs under `docs/` or revive archived trackers.

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
| 05 | [`05_simple_brain_implementation.md`](05_simple_brain_implementation.md) | Rebuild simple Grok brain + body handlers |

Execute **file by file**, **phase by phase**. Manual tests at each phase gate. Do not skip 03 before 04.

## Locked architecture

```text
Chat/Voice → Orchestrator
  → tiny system (Truth + Off/Text/Card + capability NAMES)
  → thin state (recent turns + open thread titles if any)
  → Grok thinks → structured action(s) | just_chat | unsupported
  → fetch capability if needed (finance / person / recall)
  → Auto Suggestions gate → body execute → Truth → reply
```

- **Brain** = Grok (understanding + personality — no prompt persona layer).
- **Body** = backend feature executors only.
- **Budget** ≈ **≤1k tokens** default input per turn; heavy data via fetch, not always-on dumps.
- **No** regex/overlap/embedding “second brain.” Those die in plan 04; they are not interim work.

## Out of scope for other folders

- Do not create new planning files under `docs/` (canon root is three files only after plan 03).
- Do not archive old plans — plan 04 **deletes** them.
- Do not implement Smart Thread Overlap / topic anchors / embedding-as-understanding.
