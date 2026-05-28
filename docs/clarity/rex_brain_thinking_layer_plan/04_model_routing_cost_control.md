# File 04 - Model Routing And Cost Control

Purpose: give Rex Brain a safe model-selection and cost-control contract before live chat/voice routing is enabled. This is Master Plan Phase 4 / Workstream 00.04.

Current implementation status: Phase 4 is implemented as settings, model-route planning, AIService model overrides, readiness metadata, and tests. Live chat/voice routing still remains disabled by default.

## Production Guardrail

Model routing only takes effect when a later integration phase calls `RexModelRouter` and passes the selected model into `AIService`. Current chat and voice behavior remains on `GROK_MODEL` unless explicitly integrated behind `REX_BRAIN_ROUTING_ENABLED=true`.

## Phase 4.1 - Settings Contract

Status: done.

Backend settings:

- `GROK_FAST_MODEL`
- `GROK_STANDARD_MODEL`
- `GROK_REASONING_MODEL`
- `REX_BRAIN_ROUTING_ENABLED`
- `REX_BRAIN_DEBUG_ENABLED`
- `REX_BRAIN_FAST_FIRST_ENABLED`

Acceptance:

- Existing `GROK_MODEL` remains fallback.
- Env examples document all new flags.
- Readiness reports routing state and configured model names without secrets.

## Phase 4.2 - AIService Model Override

Status: done.

`AIService.generate_response` and `AIService.stream_response` now accept optional:

- `model_override`
- `max_tokens`

Acceptance:

- No override means existing `GROK_MODEL` behavior.
- Override can be used even when `GROK_MODEL` is missing.
- Payload tests verify model and `max_tokens` selection without external Grok calls.

## Phase 4.3 - Model Profile Resolver

Status: done.

Create:

- `services/rex-api/app/services/rex_model_router.py`
- `RexModelRouter`
- `RexModelRoute`
- `RexModelLimits`
- `PROFILE_LIMITS`

Mapping:

- fast profile -> `GROK_FAST_MODEL` or `GROK_MODEL`
- standard profile -> `GROK_STANDARD_MODEL` or `GROK_MODEL`
- reasoning profile -> `GROK_REASONING_MODEL` or `GROK_MODEL`

Acceptance:

- Missing profile-specific models fall back safely.
- Missing all models reports `no_model_configured` without crashing.

## Phase 4.4 - Routing Disabled Contract

Status: done.

When `REX_BRAIN_ROUTING_ENABLED=false`:

- selected model is always `GROK_MODEL`
- effective profile is standard
- route reason is `rex_brain_routing_disabled`
- current live behavior remains unchanged

Acceptance:

- Tests verify disabled routing ignores fast/reasoning model names.

## Phase 4.5 - Escalation And Cost Profile Rules

Status: done.

Escalation sources:

- decision profile is reasoning
- explicit deep-think escalation source
- reflection is required
- high complexity score

Cost tiers:

- fast + tiny/small context -> low
- standard or medium context -> medium
- reasoning or high context -> high

Acceptance:

- Tests verify explicit deep request resolves to reasoning model and high cost tier.

## Phase 4.6 - Token And Prompt Limits

Status: done.

Profile limits:

- fast: small prompt and output budget
- standard: normal prompt and output budget
- reasoning: larger prompt and output budget, still at or below `AIService.max_prompt_characters`

Acceptance:

- Tests verify limits increase by profile and reasoning stays under the AIService prompt ceiling.

## Phase 4.7 - Safe Cost Metadata

Status: done.

`RexModelRoute.metadata()` includes:

- routing enabled
- requested profile
- effective profile
- selected model
- fallback model
- max prompt characters
- max output tokens
- cost tier
- reasons

Acceptance:

- Metadata excludes raw user text and raw financial/memory context.

## Phase 4.8 - Fast-First Optional Path

Status: done as configuration only.

`REX_BRAIN_FAST_FIRST_ENABLED` exists but remains disabled by default.

Acceptance:

- The feature flag can be reported by readiness.
- No fast-first retry behavior is active yet.

## Phase 4.9 - Cost Tests

Status: done.

Required checks:

```sh
cd services/rex-api
python3 -m pytest tests/test_ai_service.py tests/test_rex_model_router.py tests/test_readiness.py
python3 -m pytest
```

Acceptance:

- model fallback
- disabled routing
- routing enabled
- missing fast model fallback
- missing all model handling
- explicit deep request
- AIService payload override
- readiness metadata
- no external Grok calls in tests

## Phase 4 Exit Criteria

Phase 4 is complete when:

- settings exist for fast/standard/reasoning models and brain flags
- AIService accepts model overrides without changing defaults
- `rex_model_router.py` maps decisions to safe model routes
- profile token/prompt limits are tested
- readiness reports brain routing state
- env examples include new settings
- live chat/voice behavior remains unchanged until integration

## Next Workstream

Move to File 05 / Chat Integration only after model routing tests are green and routing remains disabled by default.
