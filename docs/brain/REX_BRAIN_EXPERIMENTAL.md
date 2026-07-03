# Experimental RexBrain Modules (Non-Production)

MVP production chat and voice use one path only:

```text
Chat/Voice routes -> ChatService -> ChatTurnOrchestrator -> SimpleRexBrain
```

The layered `RexBrain` stack under `services/rex-api/app/services/rex_brain*.py` and
`rex_brain_chat_service.py` remains in the tree for future work but is **not** wired
into production routes.

## Do not wire without product sign-off

- `RexBrain` / `RexBrainChatService` proactive insight routing (`needs_proactive_insight`)
- Alternate model routing or scoring layers that bypass `SimpleRexBrain`
- Any second brain path for chat or voice

Phase 5b (push notifications, balance history, production RexBrain routing) is explicitly
deferred. See `docs/clarity/GRAPHS_AND_INSIGHTS_PHASE_PLAN.md`.

## Safe to keep for tests and future design

- Contract tests in `tests/test_rex_brain_contracts.py`
- Capability tests in `tests/test_rex_brain_capabilities.py`
- Module headers that state "MVP production uses SimpleRexBrain"

When extending Rex, plug improvements into the existing `ChatTurnOrchestrator` +
`SimpleRexBrain` flow rather than activating the experimental router.
