# File 02 - Prompt Layer Contracts

Purpose: give every Rex thinking layer a versioned prompt contract before the router is integrated into live chat or voice. This is Master Plan Phase 2 / Workstream 00.02.

Current implementation status: Phase 2 is implemented as prompt contracts and tests only. Production `PromptService` remains the live base prompt path until a later integration phase enables Rex Brain routing.

## Production Guardrail

Prompt contracts are definitions, not live behavior. They must not replace `PromptService`, alter model calls, or affect chat/voice responses until routing integration is explicitly enabled behind `REX_BRAIN_ROUTING_ENABLED=true`.

## Shared Prompt Contract

Every Rex Brain layer prompt must include:

- prompt version
- layer-specific behavior
- financial-context boundary
- no direct bank-access claim
- no hidden chain-of-thought exposure
- safe confirmation rule for durable writes
- professional caution for risky legal/tax/medical/immigration topics
- a metadata schema for optional internal/debug use

## Phase 2.1 - Central Prompt Contract Module

Status: done.

Create:

- `services/rex-api/app/services/rex_brain_prompts.py`

Acceptance:

- Layer prompt contracts live in one module.
- Existing `PromptService` remains unchanged for live chat/voice.
- Prompt contracts can be imported without app startup side effects.

## Phase 2.2 - Prompt Versioning

Status: done.

Create:

- `REX_BRAIN_PROMPT_VERSION = "rex_brain_prompt_v1"`
- per-layer versions formatted as `rex_brain_prompt_v1:<layer>`

Acceptance:

- Every prompt contract returns a deterministic version string.
- Prompt metadata can identify the exact layer prompt without exposing prompt text.

## Phase 2.3 - Shared Safety Rules

Status: done.

Required rules:

- Rex only uses context supplied in the request.
- Rex must not imply direct bank access, live account access, or background monitoring.
- Clarity financial context may be incomplete, stale, or degraded.
- Rex must not reveal hidden chain-of-thought.
- Rex must not claim durable changes succeeded unless an execution result says so.
- Risky legal/tax/medical/immigration topics require caution.

Acceptance:

- Tests verify every layer prompt includes these rules.

## Phase 2.4 - Layer 0 Fast Prompt

Status: done.

Rules:

- answer quickly
- no heavy analysis
- friendly/direct Rex tone
- at most one clarification question
- voice target: 1-3 spoken sentences

Acceptance:

- Prompt explicitly keeps normal voice/chat cheap and short.

## Phase 2.5 - Layer 1 Contextual Prompt

Status: done.

Rules:

- use relevant memory and recent context when provided
- newer corrections override older memory
- admit missing context
- avoid dumping all remembered context

Acceptance:

- Prompt prevents invented recall and over-explaining.

## Phase 2.6 - Layer 2 Analytical Prompt

Status: done.

Rules:

- use Clarity financial context precisely
- separate facts, calculations, assumptions, and recommendations
- show concise math when useful
- flag missing/stale data
- never claim direct bank access

Acceptance:

- Prompt is safe for financial analysis and budget/transaction questions.

## Phase 2.7 - Layer 3 Strategic Prompt

Status: done.

Rules:

- connect finances, goals, priorities, memory, and commitments
- compare tradeoffs
- produce next actions
- preserve user autonomy
- state assumptions

Acceptance:

- Prompt supports planning without pretending certainty.

## Phase 2.8 - Layer 4 Reflective Prompt

Status: done.

Rules:

- check contradictions
- identify unsupported claims and missing assumptions
- provide a short self-check summary
- output corrected user-facing answer when needed
- do not expose hidden chain-of-thought

Acceptance:

- Prompt supports correction without defensive behavior.

## Phase 2.9 - Layer 5 Coaching Prompt

Status: done.

Rules:

- warm, direct, grounded, and practical
- use goals/rules/commitments/preferences when available
- do not fake certainty
- tie motivation to one next action
- avoid generic pep talks

Acceptance:

- Prompt supports coaching without vague motivation.

## Phase 2.10 - Prompt Contract Tests

Status: done.

Required checks:

```sh
cd services/rex-api
python3 -m pytest tests/test_rex_brain_prompts.py
python3 -m pytest tests/test_rex_brain.py tests/test_rex_brain_prompts.py tests/test_prompt_service.py
```

Acceptance:

- Every layer has a prompt contract.
- Every prompt has version and schema metadata.
- Shared safety clauses are tested.
- Prompt size budgets are tested.
- Metadata excludes prompt text and raw private context.

## Phase 2 Exit Criteria

Phase 2 is complete when:

- `rex_brain_prompts.py` exists.
- All six thinking layers have versioned prompt contracts.
- Prompt contracts include strict safety/data boundaries.
- Prompt contracts define per-layer output modes and metadata schemas.
- Tests verify required clauses, schemas, and size budgets.
- Live chat/voice behavior remains unchanged.

## Next Workstream

Move to File 03 / Context Retrieval And Budgets only after prompt contracts are green and still not integrated into live responses.
