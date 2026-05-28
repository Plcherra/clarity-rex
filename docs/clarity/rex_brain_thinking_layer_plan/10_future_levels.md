# File 10 - Future Levels

Goal: capture ambitious brain upgrades after the core layered system is stable.

## Phase 1 - Research Mode

Add optional multi-step research for questions that need external verification.

Current implementation slice:

- Rex detects current/live/web/research-shaped requests.
- If the user has not explicitly opted in, routing metadata marks the turn as
  `requires_research_opt_in`.
- Chat prompts instruct Rex to ask permission before any research behavior.
- External research adapters remain intentionally disconnected until a later
  approved phase.

Acceptance:

- User explicitly opts in before web/research behavior.

## Phase 2 - Scenario Simulation

Let Rex simulate:

- budget changes
- debt payoff paths
- savings goals
- spending tradeoffs

Current implementation slice:

- Rex detects scenario-shaped requests such as "what if", "simulate",
  payoff paths, budget changes, savings paths, and spending tradeoffs.
- Routing metadata marks the turn as `needs_scenario_simulation`.
- Chat prompts require assumptions first, then facts, estimates, tradeoffs,
  and non-guaranteed outcomes.
- Dedicated calculators remain intentionally out of scope for this slice.

Acceptance:

- Simulations state assumptions clearly.

## Phase 3 - Proactive Insights

Rex can surface:

- unusual spending
- budget drift
- upcoming commitments
- goal risks

Current implementation slice:

- Rex detects insight-shaped requests such as unusual spending, budget drift,
  upcoming commitments, goal risks, red flags, and "what should I watch".
- Routing metadata marks the turn as `needs_proactive_insight`.
- Requests for background monitoring, alerts, or recurring proactive behavior
  are marked as `requires_proactive_opt_in` unless the user setting is enabled.
- Chat prompts require Rex to use only provided Clarity context and avoid
  implying background monitoring.

Acceptance:

- User controls proactive behavior.

## Phase 4 - Personal Operating System

Connect:

- goals
- commitments
- finances
- memory
- accountability

Current implementation slice:

- Rex detects daily-focus / personal operating system requests such as
  "what should I focus on today?", "daily focus", "today's priorities", and
  "next best action".
- Routing metadata marks the turn as `needs_daily_focus`.
- Daily-focus turns route to the strategic layer and include available goals,
  commitments, finances, memory, and accountability context.
- Chat prompts require 1-3 priorities, why each matters today, and a concrete
  next action without inventing obligations.

Acceptance:

- Rex can answer "what should I focus on today?"

## Phase 5 - Multi-Turn Planning Workspace

Create structured planning sessions.

Current implementation slice:

- Rex detects planning workspace requests such as "planning session",
  "build a plan", "resume my plan", and "revise the plan".
- Routing metadata marks the turn as `needs_planning_workspace` and records
  `planning_workspace_intent` as `create`, `resume`, `edit`, or `general`.
- Planning workspace turns route to the strategic layer and include available
  goals, commitments, finances, memory, and accountability context.
- Chat prompts require objective, constraints, milestones, open decisions, and
  next revision point, while avoiding any claim that a plan was saved unless a
  write result confirms it.

Acceptance:

- Plans can be resumed and edited.

## Phase 6 - Self-Evaluation Loop

Rex scores its own answers for:

- correctness
- usefulness
- missing context
- tone fit

Current implementation slice:

- Rex marks analytical, strategic, reflective, high-complexity, research,
  simulation, proactive insight, daily-focus, and planning-workspace turns as
  `needs_self_evaluation`.
- Self-evaluation dimensions are recorded as correctness, usefulness,
  missing_context, and tone_fit.
- Chat prompts instruct Rex to run the quality check internally before
  finalizing and correct unsupported claims or tone mismatch.
- `expose_self_evaluation` remains false unless backend Rex Brain debug mode is
  enabled.
- No second LLM scoring pass is connected in this slice.

Acceptance:

- Self-eval is internal unless debug enabled.

## Phase 7 - User Preference Profiles

Support modes:

- coach
- analyst
- concise
- direct
- supportive

Current implementation slice:

- Rex detects explicit one-turn response style requests such as "coach mode",
  "analyst mode", "be concise", "be direct", and "be supportive".
- Routing metadata records `response_style_profile` as `coach`, `analyst`,
  `concise`, `direct`, `supportive`, or `default`.
- Routing metadata records `response_style_source` as `explicit_message`,
  `user_setting`, or `default`.
- Chat prompts honor the selected style for the current turn while preserving
  accuracy and safety.
- Rex is explicitly told not to treat a one-turn style request as permanent
  unless a future write result confirms a stored preference.

Acceptance:

- Preferences are user-controlled.

## Phase 8 - Long-Term Intelligence Review

Periodic review:

- stale goals
- outdated memories
- duplicate commitments
- financial blind spots

Current implementation slice:

- Rex detects long-term review requests such as "review stale goals",
  "outdated memories", "duplicate commitments", "financial blind spots",
  memory cleanup, and broader stored-context audits.
- Routing metadata marks the turn as `needs_long_term_review` and records
  `long_term_review_targets` as any combination of `goals`, `memories`,
  `commitments`, and `financial_blind_spots`.
- Long-term review turns route to the reflective layer so Rex treats cleanup as
  candidate review rather than automatic execution.
- Chat prompts require Rex to use only provided Clarity context, propose
  cleanup candidates, and ask for explicit confirmation before editing,
  deleting, deactivating, or merging anything.

Acceptance:

- Rex proposes cleanup, user confirms changes.

## Phase 9 - Confirmed Action Preview

Bridge user-reviewed recommendations into safe action previews for:

- memory cleanup
- goal updates
- commitment merges
- budget/category/rule edits
- transaction corrections
- planning workspace saves

Current implementation slice:

- Rex detects confirmation-shaped requests such as "apply those changes",
  "save these changes", "delete those", "merge these", and "go ahead and
  apply".
- Routing metadata marks the turn as `needs_confirmed_action_preview`, records
  `confirmed_action_intent`, and records `confirmed_action_targets`.
- Confirmed action preview turns route to the reflective layer so Rex checks
  the intended mutation before any write behavior.
- Routing metadata includes a preview-only `pending_action_contract` until a
  real pending action has an id, target ids, exact proposed diff, confirmation
  status, and execution result.
- Chat prompts require Rex to summarize exact candidate changes, ask one
  clarification question when ambiguous, and never claim a write happened unless
  an execution result confirms success.

Acceptance:

- Rex previews exact changes before any mutation.
- Destructive actions remain behind explicit confirmation.

## Phase 10 - Future Levels Exit Gate

Purpose:

- Define the release gate for File 10 future-level behavior.
- Keep ambitious Rex Brain features safe, measurable, reversible, and voice-safe
  before wider phone testing.

Release blockers:

- Safe routing metadata is incomplete, contains raw user text, raw financial
  rows, memory bodies, prompt text, secrets, credentials, or file contents.
- Research-shaped requests can answer with live/current/web facts before user
  opt-in.
- Proactive monitoring, alerts, or recurring behavior can be promised before
  user opt-in.
- Long-term review can edit, delete, merge, deactivate, or rewrite durable
  user truth without explicit confirmation.
- Confirmed action preview can execute mutations without a pending-action
  contract, target ids, exact diff, confirmation status, and execution result.
- Normal voice turns can route to reasoning or high context budget because
  context is available rather than because the user's request truly needs it.
- Golden evals do not cover the future-level routes.
- Rollback requires a mobile reinstall or code deploy instead of env flags plus
  backend restart.

Required verification:

```sh
cd services/rex-api
python3 -m pytest tests/test_rex_brain.py \
  tests/test_rex_brain_prompts.py \
  tests/test_chat_service.py \
  tests/test_rex_brain_voice_integration.py \
  tests/test_rex_model_router.py -q
python3 -m pytest
```

Manual release gate:

- Backend `/ready` reports the intended Rex Brain rollout stage.
- `REX_BRAIN_ROUTING_ENABLED=false` and `REX_BRAIN_ROLLOUT_STAGE=disabled`
  still preserve current behavior.
- When routing is enabled intentionally, VPS logs show metadata-only
  `rex_brain_turn` events.
- Chat smoke test passes: casual, finance analysis, Deep Think, memory recall,
  long-term review, and confirmed action preview.
- Voice smoke test passes: normal voice remains responsive, explicit deep voice
  can escalate, and voice does not expose raw routing internals.
- Rollback path is documented and tested:

```sh
cd /opt/clarity/current
./scripts/vps_restart_rex_api.sh
```

Acceptance:

- File 10 future-level behavior is blocked unless opt-in, confirmation,
  observability, evals, voice latency, and rollback gates all pass.
- Any future write-capable feature must prove confirmation and execution-result
  contracts before it can leave preview-only mode.
