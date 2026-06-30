# Memory Trust Audit

**Date:** 2026-06-25  
**Rule:** Nothing is saved to durable Knows/Goals memory unless the user sees an editable confirm card and explicitly confirms. Chat search stays separate from saved memory.

## Target invariants

1. One production brain (`SimpleRexBrain` + `ChatTurnOrchestrator`) for chat and voice.
2. All durable writes go through `DurableWriteProposal` → pending action → confirm card → frozen `apply_snapshot`.
3. Mobile receives `write_proposals` only (no hidden discipline metadata).
4. After confirm, item is visible in Knows or Goals without manual refresh.
5. No hidden side writes (e.g. person entity materialization on memory save).

## Pre-reset gaps (addressed by Memory Trust Reset implementation)

| Risk | Severity | Status |
|------|----------|--------|
| Simple memory auto-save without card | High | Routed through `durable_write` proposal |
| Goal/commitment immediate save | High | Routed through `durable_write` proposal |
| Hidden person entity materialization | High | Disabled on chat apply path |
| Plan merge without disclosure | High | Merge target shown in proposal text |
| Fat `memory_changes.records` to mobile | Medium | Slim `write_proposals` payload |
| Goals tab stale after chat save | Medium | Refresh `accountabilityProvider` on apply |
| Experimental `rex_brain_*` stack | Low | Archived; production uses `rex_brain_contracts` only |

## Write path categories

### Requires confirm card (chat/voice)

- Flat memory (`write_kind: memory`)
- Plans, milestones, commitments (explicit + conversational)
- Plan/commitment updates
- Entity events (conversational discipline)
- Deletes (existing delete pending flow)

### Manual UI (user is the form)

- Knows/Goals REST CRUD — user fills form and taps Save

### Session-only (not Knows)

- Chat messages, `conversations.pending_action` staging, LLM `clarity_action` financial proposals

## Production brain path

```text
User turn → ChatTurnOrchestrator
  → DurableWriteConfirmService (pending apply/reject)
  → ConversationalPlanService
  → GoalCommandService (propose)
  → MemoryTurnService (propose)
  → SimpleRexBrain + Grok
```

## Related docs

- [REX_BRAIN_RULES.md](./REX_BRAIN_RULES.md)
- [REX_BRAIN_ARCHITECTURE.md](./REX_BRAIN_ARCHITECTURE.md)
- [REX_BRAIN_TRUST_RELIABILITY_PLAN.md](./REX_BRAIN_TRUST_RELIABILITY_PLAN.md)
