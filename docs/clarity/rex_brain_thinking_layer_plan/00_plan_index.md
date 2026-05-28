# Rex Brain Thinking Layer Plan

Purpose: turn Rex from a flat chatbot into a routed, layered assistant that can answer fast when the request is simple and think deeply when the request needs financial reasoning, memory, goals, or self-checking.

Working rule: progress one file and one phase at a time. Example: "File 01 phase 2" means implement only that phase, verify it, then pause for review.

Current implementation status:

- `00.01` / File 01 is complete: typed contracts, deterministic router, safe metadata, and router tests.
- `00.02` / File 02 is complete: versioned prompt contracts, safety clauses, schemas, and prompt tests.
- `00.03` / File 03 is complete: context budgets, financial scopes, memory ranking, safety filtering, and context tests.
- `00.04` / File 04 is complete: settings, AIService overrides, model resolver, cost limits, readiness metadata, and model routing tests.
- `00.05` / File 05 is complete: non-streaming and streaming chat can use Rex Brain prompt/model routing behind `REX_BRAIN_ROUTING_ENABLED`, while disabled routing preserves current chat behavior.
- `00.06` / File 05 voice scope is complete: upload and streaming voice turns now pass `RexBrainChannel.VOICE`, keep short caps by default, and allow explicit deep voice escalation.
- `00.07` / File 06 is complete: memory correction and extraction candidates now carry safe Rex Brain metadata while risky writes remain confirmable and financial category learning stays separate.
- `00.08` / File 07 is complete: chat has a compact per-message Deep Think toggle, mobile sends `deep_think`, backend chat routes accept it, and explicit requests escalate the Rex Brain decision when routing is enabled.
- `00.09` / File 08 is complete: metadata-only Rex Brain observations, local golden route evals, chat observation hooks, and release-gate docs are in place.
- `00.10` / File 09 is complete: staged rollout gating, rollout readiness metadata, env templates, and deployment docs are in place.
- Current cursor: `00.11` / File 10 - Future levels.
- Live Rex chat/voice routing remains disabled until `REX_BRAIN_ROUTING_ENABLED=true`; the code paths are wired and ready behind the flag.

Plan files:

1. `01_foundation_router.md` - core objects, router, input/output contracts.
2. `02_prompt_layers.md` - layer prompts, response contracts, tone rules.
3. `03_context_retrieval.md` - memory, finance, goals, accountability, pending items.
4. `04_model_routing_cost_control.md` - model profiles, escalation, budgets, fallback.
5. `05_chat_voice_integration.md` - chat integration now; voice-first integration is the next cursor from the master plan.
6. `06_memory_learning_feedback.md` - durable learning, corrections, manual feedback loop.
7. `07_ui_deep_think_experience.md` - Deep Think toggle, debug hints, user-facing polish.
8. `08_observability_eval_tests.md` - logging, evals, regression tests, quality gates.
9. `09_rollout_deployment.md` - env vars, migration, VPS rollout, release testing.
10. `10_future_levels.md` - research mode, simulations, proactive intelligence.

Global definition of done:

- No live route changes without tests.
- Every layer has a clear cost profile.
- Rex never claims access to data it does not have.
- Rex can explain why it escalated when debug mode is enabled.
- Voice and chat share the same brain path.
- Financial answers use the financial read model, not duplicate calculations.
- Memory updates stay confirmable when risky.
- Release checklist includes phone testing and backend readiness.

