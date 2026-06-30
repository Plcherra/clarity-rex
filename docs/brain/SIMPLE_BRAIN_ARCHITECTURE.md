# Simple Brain Architecture

One production Rex Brain for chat and voice. All durable writes go through confirm cards.

## Production path (chat + voice)

```text
ChatTurnOrchestrator
  → save intent? → DurableWriteService.propose → write_proposals + pending_action
  → pending confirm? → DurableWriteApplier.apply → DB
  → recall intent? → ChatRecallService (read-only excerpts)
  → inventory intent? → SavedKnowledgeOverviewService → prompt
  → else → Grok (no save claims)
```

## Invariants

- Chat/voice durable writes: only `DurableWriteProposal` → card confirm → `DurableWriteApplier`
- Chat search: read-only; never auto-promotes to memory
- Knows tab vs "what do you know?": same `SavedKnowledgeOverviewService` snapshot
- Knows manual CRUD: REST routes only; no hidden materializer/merge/reclassify writes
- Grok must not offer or claim saves without a backend `write_proposal`

## Knows tab

`GET /saved-knowledge/overview` returns the deduped snapshot used by inventory prompts.

## Manual Knows edit

REST CRUD on `/memory`, `/entities`, `/plans`, etc. No auto person materialization on generic LTM create.

## Mobile

`write_proposals` → `ClarityActionCardsStrip` → `write_confirmation` (text and voice).

## Disabled bypass paths

- `GoalCommandReclassifier` direct writes
- `save_plan` pending type (folded into `durable_write`)
- Auto merge on REST/chat create unless `merge_disclosed_to` is set
- Auto person materialization on generic memory create
