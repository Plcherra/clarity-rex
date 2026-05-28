# File 08 - Observability, Evals, And Tests

Goal: know whether Rex is smarter, cheaper, and safer after routing without logging private content.

Status: `00.09` implementation complete for the first production-safe observability and eval gate. Rex Brain now has metadata-only observation events, local golden route eval fixtures, chat-service observation hooks, and release checklist updates.

## Phase 1 - Routing Unit Tests

Implemented:

- Router tests already cover 25+ deterministic examples across casual, contextual, analytical, strategic, reflective, coaching, voice, attachment, and safety-sensitive turns.
- Added golden eval fixtures for casual, finance, strategic, reflective, coaching, and voice cases.

Acceptance:

- Evals run locally without external API calls.
- Fixtures assert expected layer and model profile.

## Phase 2 - Prompt Snapshot Tests

Current status:

- Prompt contract tests verify version, schema, safety clauses, and size budgets.

Future scope:

- Add strict text snapshots only after prompts stabilize enough that snapshot churn is useful.

Acceptance:

- Prompt regressions are intentional.

## Phase 3 - Chat Service Contract Tests

Implemented:

- Chat service now emits metadata-only Rex Brain observations for planned and completed turns.
- Tests verify observer events do not contain raw user text.

Acceptance:

- Existing chat behavior remains feature-flagged by routing settings.
- Observer payloads contain request id, channel, layer, profile, budget, latency class, status, and routing state.

## Phase 4 - Voice Contract Tests

Current status:

- Existing voice integration tests verify voice channel routing, normal low-latency voice behavior, and explicit deep voice escalation.

Future scope:

- Attach voice request ids to observability once voice stream tracing is expanded.

Acceptance:

- Voice test suite stays stable.
- Voice remains low-latency by default.

## Phase 5 - Golden Conversation Evals

Implemented fixture file:

- `services/rex-api/tests/fixtures/rex_brain_evals.json`

Cases:

- casual greeting
- spending analysis
- strategic goal plan
- reflective self-check
- coaching
- voice fast turn
- voice explicit deep turn

Acceptance:

- Evals can run locally without external API.

## Phase 6 - Production Logs

Implemented:

- `RexBrainObserver` emits metadata-only `rex_brain_turn` log lines.
- Logs include request id, channel, status, layer, model profile, effective model profile, context budget, output mode, latency class, cost tier, routing state, escalation source, and safe routing reasons.

Safety rules:

- Do not log raw user text.
- Do not log raw prompt text.
- Do not log raw financial rows.
- Do not log memory bodies.
- Do not log file contents.

Acceptance:

- Tests verify sensitive user/financial strings are absent from rendered observation payloads.

## Phase 7 - Quality Metrics

Current log-derived metrics:

- escalation rate by `layer` and `effective_model_profile`
- fast vs reasoning usage by `cost_tier`
- voice vs chat split by `channel`
- failure classes by `status=failed` and `error_class`

Future scope:

- Add latency duration from route entry to completion.
- Add metrics dashboard after production logging volume is understood.

Acceptance:

- Metrics can be inspected from VPS logs or future dashboard.

## Phase 8 - Release Gate

Updated checklist:

- Backend tests pass.
- Mobile tests pass on the Mac build machine.
- Backend `/ready` passes.
- Phone release helper installs the app.
- Manual dashboard/chat/voice smoke tests pass.
- Rex Brain routing remains disabled unless intentionally enabled.
- If routing is enabled, VPS logs include metadata-only `rex_brain_turn` events.

Acceptance:

- Checklist is updated before the next device release.
