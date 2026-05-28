# Rex Brain Master Plan

## Executive Summary

Rex Brain wins because it turns Rex into a deterministic, inspectable assistant architecture instead of a single flat LLM call. Simple conversation stays fast and cheap. Financial analysis, planning, memory recall, coaching, and self-checking escalate only when the request needs it. The system stays production-safe because routing is disabled by default, every layer has an explicit Input -> Output contract, and chat plus voice use the same brain path without forcing voice into slow reasoning by accident.

The core principle is progressive enhancement: current Rex behavior remains intact until a feature flag enables routing. Each phase is small enough for one focused implementation session, has concrete tests, and can be rolled back without data migration.

## Overall Architecture Diagram

```text
User turn
  |
  v
Chat UI / Voice UI
  |
  v
Backend route (/chat or /voice/stream)
  |
  v
RexBrainInput builder
  |  - message
  |  - channel: chat | voice
  |  - conversation metadata
  |  - attachment flags
  |  - available context flags
  |  - explicit deep-think flag
  |
  v
RexThinkingRouter
  |  deterministic scoring + precedence
  v
RexBrainDecision
  |  - layer
  |  - model profile
  |  - context budget
  |  - output contract
  |  - routing reasons
  |
  +-------------------------+
  |                         |
  v                         v
Fast Path               Deep Path
Layer 0/1               Layer 2/3/4/5
small context           selected rich context
low latency             higher reasoning budget
short output            structured analysis/checking
  |                         |
  +-----------+-------------+
              |
              v
Prompt composer
  |
  v
AIService model resolver
  |
  v
Grok API
  |
  v
Response post-processing
  |
  +--> memory candidate pipeline
  +--> clarity action extraction
  +--> debug metadata when enabled
  |
  v
Chat / voice response
```

## Updated File Structure

Backend:

```text
services/rex-api/app/services/
  rex_brain.py
  rex_brain_context.py
  rex_brain_contracts.py
  rex_brain_prompts.py
  rex_model_router.py
  rex_observability.py
  chat_service.py
  ai_service.py
```

Backend tests:

```text
services/rex-api/tests/
  test_rex_brain.py
  test_rex_brain_context.py
  test_rex_brain_prompts.py
  test_rex_model_router.py
  test_rex_brain_chat_integration.py
  test_rex_brain_voice_integration.py
  test_rex_brain_observability.py
```

Mobile:

```text
apps/mobile/lib/features/assistant/
  chat/
  voice/
  brain/
    rex_brain_debug_models.dart
    rex_deep_think_state.dart
```

Docs:

```text
docs/clarity/rex_brain_thinking_layer_plan/
  00_rex_brain_master_plan.md
  01_foundation_router.md
  02_prompt_layers.md
  03_context_retrieval.md
  04_model_routing_cost_control.md
  05_chat_voice_integration.md
  06_memory_learning_feedback.md
  07_ui_deep_think_experience.md
  08_observability_eval_tests.md
  09_rollout_deployment.md
  10_future_levels.md
```

## Core Contracts

### Fast Path Contract

Input:

- `RexBrainInput`
- recent conversation summary only
- optional small memory hints
- no raw transaction dumps

Output:

- plain assistant text
- optional memory/action candidates
- optional debug metadata when enabled

Rules:

- target low latency
- no deep financial calculations
- do not claim unavailable context
- answer in 1-4 short paragraphs
- for voice, prefer 1-3 spoken sentences

### Deep Path Contract

Input:

- `RexBrainInput`
- selected financial context budget
- selected memory/goals/accountability context
- layer-specific prompt contract

Output:

- plain user-facing answer by default
- optional structured internal metadata
- optional memory/action candidates
- optional self-check summary in debug mode only

Rules:

- use reasoning model profile
- separate facts, assumptions, and recommendations
- cite app context boundaries
- refuse or caution where needed
- never expose hidden chain-of-thought

### Layer Contracts

Layer 0 Fast:

- Input: message + recent chat
- Output: concise response
- Model profile: fast
- Max context: tiny

Layer 1 Contextual:

- Input: message + relevant memory + recent chat
- Output: answer grounded in recall
- Model profile: standard
- Max context: small

Layer 2 Analytical:

- Input: message + financial summary/selected records
- Output: factual analysis, math when useful, clear caveats
- Model profile: reasoning
- Max context: medium

Layer 3 Strategic:

- Input: message + finances + goals + plans + relevant memory
- Output: tradeoffs, decision frame, next actions
- Model profile: reasoning
- Max context: medium/high

Layer 4 Reflective:

- Input: draft answer or full turn context
- Output: consistency check, missing assumptions, corrected response when needed
- Model profile: reasoning
- Max context: selected only

Layer 5 Coaching:

- Input: message + preferences + commitments + goals
- Output: supportive coaching grounded in user facts
- Model profile: fast/standard unless complex
- Max context: small/medium

## Revised 10-Phase Plan

### Phase 1 - Foundation Router Contracts

Goal:

Create the typed Rex Brain foundation with deterministic routing, explicit Input -> Output contracts, and no production behavior change.

Files to create/modify:

- `services/rex-api/app/services/rex_brain.py`
- `services/rex-api/app/services/rex_brain_contracts.py`
- `services/rex-api/tests/test_rex_brain.py`
- `docs/clarity/rex_brain_thinking_layer_plan/01_foundation_router.md`

Acceptance criteria:

- Router handles fast, contextual, analytical, strategic, reflective, and coaching routes.
- Route decisions include layer, model profile, context budget, output mode, reasons, and latency class.
- At least 25 routing examples are tested.
- Chat and voice behavior are unchanged while routing is not integrated.

Risks and mitigations:

- Risk: keyword routing over-escalates.
- Mitigation: precedence tests and false-positive fixtures.

Estimated effort:

- 1-2 focused sessions.

### Phase 2 - Prompt Layer Contracts

Goal:

Create versioned prompt contracts for each layer, with strict safety boundaries and optional internal metadata schemas.

Files to create/modify:

- `services/rex-api/app/services/rex_brain_prompts.py`
- `services/rex-api/tests/test_rex_brain_prompts.py`
- `docs/clarity/rex_brain_thinking_layer_plan/02_prompt_layers.md`

Acceptance criteria:

- Every layer has a versioned prompt.
- Every prompt states data limits, no-bank-access rule, and no hidden chain-of-thought rule.
- Analytical and strategic prompts define facts/assumptions/recommendations behavior.
- Prompt tests verify required clauses.

Risks and mitigations:

- Risk: prompts become too long.
- Mitigation: prompt tests include max character checks.

Estimated effort:

- 1 focused session.

### Phase 3 - Context Retrieval And Budgets

Goal:

Build controlled context selection so Rex uses enough information without flooding the model or leaking irrelevant sensitive data.

Files to create/modify:

- `services/rex-api/app/services/rex_brain_context.py`
- `services/rex-api/app/services/chat_service.py`
- `services/rex-api/tests/test_rex_brain_context.py`
- `docs/clarity/rex_brain_thinking_layer_plan/03_context_retrieval.md`

Acceptance criteria:

- Context budget tiers exist: tiny, small, medium, high.
- Financial context can be summary-only, category rollup, monthly rollup, or selected records.
- Memory context ranks corrections before facts.
- Missing/degraded financial context produces metadata, not failure.
- Tests cover empty context, degraded context, large transaction history, and corrected memory.

Risks and mitigations:

- Risk: token overflow.
- Mitigation: hard context character budgets before prompt composition.

Estimated effort:

- 2 focused sessions.

### Phase 4 - Model Routing And Cost Control

Goal:

Allow model selection by profile while preserving `GROK_MODEL` fallback and keeping routing disabled by default.

Files to create/modify:

- `services/rex-api/app/config.py`
- `services/rex-api/app/services/ai_service.py`
- `services/rex-api/app/services/rex_model_router.py`
- `services/rex-api/tests/test_ai_service.py`
- `services/rex-api/tests/test_rex_model_router.py`
- `deploy/templates/rex-api.env.example`
- `services/rex-api/.env.example`

Acceptance criteria:

- Settings support fast, standard, and reasoning models.
- Existing `GROK_MODEL` remains fallback.
- `AIService` accepts optional model override.
- Tests verify disabled routing, enabled routing, missing model fallback, and explicit deep-think escalation.
- No external API calls in tests.

Risks and mitigations:

- Risk: production env missing new model names.
- Mitigation: fallback to `GROK_MODEL`, readiness reports configured models without secrets.

Estimated effort:

- 1-2 focused sessions.

### Phase 5 - Chat Integration

Goal:

Use Rex Brain decisions in chat while preserving current chat behavior behind a feature flag.

Files to create/modify:

- `services/rex-api/app/services/chat_service.py`
- `services/rex-api/app/routes/chat.py`
- `services/rex-api/tests/test_rex_brain_chat_integration.py`
- `services/rex-api/tests/test_chat_routes.py`

Acceptance criteria:

- Routing disabled means current behavior is byte-for-byte equivalent where practical.
- Routing enabled selects prompt layer and model profile.
- Streaming and non-streaming chat use the same decision.
- Optional debug metadata can be emitted without exposing raw private context.
- Existing chat route tests pass.

Risks and mitigations:

- Risk: streaming changes break UI.
- Mitigation: event contract tests for conversation/token/done events.

Estimated effort:

- 2 focused sessions.

### Phase 6 - Voice-First Integration

Goal:

Make voice use Rex Brain without slowing normal voice turns.

Files to create/modify:

- `services/rex-api/app/services/voice_stream_session.py`
- `services/rex-api/app/routes/voice_stream.py`
- `services/rex-api/app/services/chat_service.py`
- `services/rex-api/tests/test_rex_brain_voice_integration.py`
- `services/rex-api/tests/test_voice_stream_routes.py`

Acceptance criteria:

- Voice has a strict fast path for normal turns.
- Voice escalates only for explicit deep-thinking phrases or clearly complex questions.
- Voice response target is short unless user asks for depth.
- Voice uses same conversation id and memory path as chat.
- Tests verify fast voice turn, deep voice turn, interruption, and retry behavior.

Risks and mitigations:

- Risk: deep reasoning makes voice feel slow.
- Mitigation: voice latency class forces fast/standard unless escalation is explicit or high confidence.

Estimated effort:

- 2 focused sessions.

### Phase 7 - Memory Learning And Feedback

Goal:

Connect brain decisions to memory learning, corrections, and financial learning without unsafe auto-writes.

Files to create/modify:

- `services/rex-api/app/services/memory_candidate_service.py`
- `services/rex-api/app/services/memory_discipline_service.py`
- `services/rex-api/app/services/chat_service.py`
- `services/rex-api/tests/test_memory_candidate_service.py`
- `services/rex-api/tests/test_memory_discipline_service.py`
- `docs/clarity/rex_brain_thinking_layer_plan/06_memory_learning_feedback.md`

Acceptance criteria:

- Memory candidates include brain metadata.
- Risky corrections remain confirmable.
- Financial category learning remains separate from personal memory.
- Tests cover "remember this", "that was wrong", and category feedback.

Risks and mitigations:

- Risk: Rex saves noisy or temporary memory.
- Mitigation: memory discipline gates by risk and confidence.

Estimated effort:

- 2 focused sessions.

### Phase 8 - UI Deep Think Experience

Goal:

Expose Rex Brain in the UI only where it improves trust and control.

Files to create/modify:

- `apps/mobile/lib/features/assistant/chat/presentation/widgets/chat_input_bar.dart`
- `apps/mobile/lib/features/assistant/chat/application/chat_controller.dart`
- `apps/mobile/lib/features/assistant/voice/application/voice_call_controller.dart`
- `apps/mobile/lib/features/assistant/brain/`
- `apps/mobile/test/`

Acceptance criteria:

- Deep Think toggle is available but not visually heavy.
- Debug metadata is hidden in release by default.
- Chat can request deep thinking explicitly.
- Voice UI shows listening/thinking/speaking clearly.
- Widget tests cover toggle and hidden debug behavior.

Risks and mitigations:

- Risk: UI becomes cluttered.
- Mitigation: keep Deep Think as a compact control and debug behind settings.

Estimated effort:

- 2 focused sessions.

### Phase 9 - Observability, Evals, And Release Gates

Goal:

Make brain quality measurable and regressions catchable before phone testing.

Files to create/modify:

- `services/rex-api/app/services/rex_observability.py`
- `services/rex-api/tests/test_rex_brain_observability.py`
- `docs/clarity/device_release_checklist.md`
- `docs/clarity/rex_brain_thinking_layer_plan/08_observability_eval_tests.md`

Acceptance criteria:

- Logs include request id, layer, model profile, latency class, status, and error class.
- Logs exclude raw user text and raw financial records by default.
- Golden eval fixtures exist for casual, finance, strategic, reflective, coaching, and voice turns.
- Release gate includes backend tests, mobile tests, readiness, release install, and manual smoke test.

Risks and mitigations:

- Risk: logs leak private information.
- Mitigation: metadata-only logging by default, content logging never enabled in production.

Estimated effort:

- 1-2 focused sessions.

### Phase 10 - Staged Rollout And Future Levels

Goal:

Ship safely, then prepare advanced features after the core is stable.

Files to create/modify:

- `deploy/templates/rex-api.env.example`
- `services/rex-api/README.md`
- `docs/deployment.md`
- `docs/clarity/rex_brain_thinking_layer_plan/09_rollout_deployment.md`
- `docs/clarity/rex_brain_thinking_layer_plan/10_future_levels.md`

Acceptance criteria:

- Routing can be enabled in stages: logging only, fast/contextual, analytical, strategic/reflective, UI deep think.
- Rollback is one env flag plus backend restart.
- VPS flow uses `./scripts/vps_restart_rex_api.sh`.
- Phone flow uses `./scripts/mobile_release_run.sh`.
- Future research/simulation/proactive features stay out of core release until stable.

Risks and mitigations:

- Risk: feature flag drift across VPS and mobile.
- Mitigation: readiness endpoint reports brain routing state and model configuration.

Estimated effort:

- 1 focused session for rollout docs, future work deferred.

## Non-Negotiable Production Rules

- Current chat and voice behavior stays unchanged until `REX_BRAIN_ROUTING_ENABLED=true`.
- Voice defaults to low-latency fast path.
- Financial answers must use supplied app context and must not imply direct bank access.
- No raw secrets, credentials, or unnecessary raw transaction dumps enter prompts.
- Memory writes that could change durable user truth require confirmation unless low-risk and explicitly allowed.
- Debug metadata is opt-in and safe to display.
- Every phase ships with tests or a documented reason tests are not applicable.
- Every rollout has a rollback path.

