# File 01 - Foundation Router Contracts

Purpose: build the typed Rex Brain decision layer before any live chat or voice routing changes. This file is the implementation plan for Master Plan Phase 1 / Workstream 00.01.

Current implementation status: Phase 1 is implemented in code and tests. Phase 2 starts the next time we wire prompts or live routing.

## Production Guardrail

The router is a planner only. It must not change production prompts, models, streaming events, memory writes, or voice behavior until a later integration phase enables `REX_BRAIN_ROUTING_ENABLED=true`.

## Core Input Contract

`RexBrainInput` must be buildable by both chat and voice without requiring optional context.

Fields:

- `message`: current user text.
- `channel`: `chat` or `voice`.
- `conversation_id`: optional thread id.
- `has_file`: whether this turn has an attachment.
- `has_financial_context`: whether app financial context is available.
- `has_structured_memory`: whether memory context is available.
- `has_goals`: whether goal context is available.
- `has_pending_commitments`: whether commitments/pending items are available.
- `conversation_message_count`: available history depth.
- `user_requested_deep_thinking`: explicit user escalation.

Safety rule: missing optional context must never crash routing and must never be represented as raw context inside metadata.

## Core Output Contract

`RexBrainDecision` is safe to log and safe to expose in debug UI because it contains no user text, raw financial records, secrets, or prompt content.

Fields:

- `layer`: selected thinking layer.
- `model_profile`: fast, standard, or reasoning.
- `complexity_score`: deterministic score used for tests/debugging.
- `context_budget`: tiny, small, medium, or high.
- `output_mode`: concise text, grounded text, analysis, strategic plan, reflective check, or coaching.
- `latency_class`: realtime, fast, standard, or deep.
- `cost_tier`: low, medium, or high.
- `reasons`: deterministic route reasons.
- `escalation_source`: primary reason for escalation.
- `expected_context_sources`: metadata-only source list.
- `needs_financial_context`, `needs_memory_context`, `needs_reflection`: compatibility booleans.

## Phase 1.1 - Contract Extraction

Status: done.

Create:

- `services/rex-api/app/services/rex_brain_contracts.py`

Acceptance:

- Contract enums and dataclasses live outside router implementation.
- Existing imports from `rex_brain.py` remain compatible.
- Metadata serialization is deterministic.

## Phase 1.2 - Full Input Contract

Status: done.

Add chat/voice-ready fields to `RexBrainInput`:

- channel
- conversation id
- goals availability
- pending commitments availability

Acceptance:

- Chat and voice can pass the same contract.
- Missing optional context returns a valid decision.
- Voice is distinguishable without changing live voice behavior.

## Phase 1.3 - Full Decision Metadata

Status: done.

Add:

- context budget
- output mode
- latency class
- cost tier
- escalation source
- expected context sources

Acceptance:

- Metadata includes only safe routing fields.
- Metadata includes no user text, transaction rows, credentials, prompts, or memory body text.

## Phase 1.4 - Deterministic Router V1

Status: done.

Router handles:

- casual messages
- contextual memory recall
- financial analysis
- code/debug analysis
- tax/legal/medical caution language
- strategic goals/planning
- reflective/self-check requests
- coaching/accountability requests
- attachments
- multi-step requests
- explicit deep-think requests
- voice fast-path turns

Acceptance:

- At least 25 examples are tested.
- False-positive matching uses word boundaries for single-word terms.
- `first` does not match `irs`.
- Voice normal turns prefer realtime/standard over deep latency.

## Phase 1.5 - Layer Precedence

Status: done.

Precedence:

1. reflective/self-check
2. safety-sensitive caution
3. explicit deep thinking with goals/commitments
4. strategic planning/goals
5. coaching/accountability
6. analytical/financial/code
7. contextual recall
8. multi-step/file contextual
9. fast casual/default

Acceptance:

- Mixed budget + goals routes strategic.
- Coaching requests that mention spending remain coaching unless the user asks for analysis.
- Tax/legal sensitive turns route analytical for caution.

## Phase 1.6 - Voice Fast-Path Contract

Status: done.

Voice routing rules:

- Normal voice turns use realtime latency.
- Normal analytical voice turns use standard model profile, not reasoning, unless high confidence or explicit deep thinking.
- Explicit voice deep-think may use reasoning, but latency class stays `standard`, not `deep`.

Acceptance:

- Tests cover fast voice, analytical voice, coaching voice, and explicit deep voice escalation.

## Phase 1.7 - Threshold Configuration

Status: done.

Create `RexThinkingRouterConfig` with:

- deep score threshold
- voice deep score threshold
- max fast words
- max fast message length

Acceptance:

- Tests can override thresholds.
- Defaults are conservative.

## Phase 1.8 - Hardening Tests

Status: done.

Required checks:

```sh
cd services/rex-api
python3 -m pytest tests/test_rex_brain.py
python3 -m pytest tests/test_ai_service.py tests/test_chat_routes.py tests/test_rex_brain.py
```

Acceptance:

- Router test file has 25+ deterministic examples.
- Existing chat/AI tests still pass.
- No live API calls are required.

## Phase 1 Exit Criteria

Phase 1 is complete when:

- `rex_brain_contracts.py` exists.
- `rex_brain.py` imports and uses the contract objects.
- Router decisions include layer, model profile, context budget, output mode, latency class, reasons, cost tier, escalation source, and expected context sources.
- `tests/test_rex_brain.py` has at least 25 route examples.
- Existing chat tests still pass.
- Production behavior is unchanged because the router is not integrated into live chat/voice model selection yet.

## Next Workstream

Move to File 02 / Prompt Layer Contracts only after Phase 1 tests are green and the router remains disabled for production behavior.
