# Experimental Rex Brain (archived)

These modules are **not** used by the production chat/voice path.

Production uses `SimpleRexBrain` + `ChatTurnOrchestrator`.

| Module | Status |
|--------|--------|
| `rex_brain_contracts.py` | **Kept** — shared channel/types for chat + voice |
| `rex_brain.py`, `rex_brain_*` (except contracts) | Experimental — tests only |

Do not wire experimental modules into `ChatService` without an explicit product decision.
