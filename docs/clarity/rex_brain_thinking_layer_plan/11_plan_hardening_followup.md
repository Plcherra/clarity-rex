# File 11 - Plan Hardening Follow-Up

Goal: fix the remaining plan and contract gaps found after the File 10 review before treating Rex Brain as ready for broader testing.

Work one phase at a time. Each phase should be implemented, tested, and reviewed before moving to the next.

Status: complete. This file is now closed out and the plan cursor has moved to release validation and phone testing.

## Phase 1 - Voice Routing Scoring Guard

Status: complete.

Problem:

- Voice can still escalate to reasoning because available context adds score before user intent is judged.
- Full-context voice turns can become slow even when the user asked a normal question.

Required fix:

- `RexThinkingRouter` now subtracts context-availability score before deciding
  whether a voice turn should use the reasoning profile.
- Normal voice turns keep a small context budget unless explicit deep thinking,
  file input, or high intent complexity requires more.
- Explicit deep-thinking voice requests still use reasoning.
- Clearly complex voice turns can still escalate when request intent, not merely
  available context, passes the voice threshold.
- Regression tests cover voice with financial context, structured memory, goals,
  and pending commitments.

Acceptance:

- Normal full-context voice questions stay standard/realtime or standard latency, not deep.
- Explicit voice deep-think still routes to reasoning.
- Tests prove context flags alone do not trigger voice reasoning.

## Phase 2 - File 10 Phase 10 Exit Gate

Status: complete.

Problem:

- `10_future_levels.md` previously ended at Phase 9 and had no final exit criteria.

Required fix:

- Added Phase 10 as the Future Levels exit gate.
- Defined what must be true before future-level behavior is considered ready:
  - safe routing metadata
  - opt-in gates
  - confirmation gates
  - eval coverage
  - voice latency safety
  - rollback path
- Added release blockers, verification commands, manual smoke gates, and
  rollback requirements.

Acceptance:

- File 10 has a clear Phase 10.
- Phase 10 lists specific release blockers and verification commands.

## Phase 3 - Confirmed Action Pending-Action Contract

Status: complete.

Problem:

- Phase 9 has a prompt guard, but no durable pending-action contract.
- Rex can detect "apply/delete/merge" language, but there is no action batch id, target ids, exact diff, confirmation status, or execution result.

Required fix:

- Added `RexPendingActionContract` before any mutation path is connected.
- Contract fields include:
  - `pending_action_id`
  - `action_intent`
  - `target_type`
  - `target_ids`
  - `proposed_diff`
  - `requires_confirmation`
  - `confirmed_at`
  - `executed_at`
  - `execution_result`
- Confirmed action preview metadata now carries a preview-only pending-action
  contract.
- Chat prompts explicitly say preview turns are non-mutating unless a real
  pending-action contract exists and a write/execution result confirms success.

Acceptance:

- Phase 9 cannot be mistaken for an execution feature.
- Tests or docs prove confirmed action preview remains non-mutating.

## Phase 4 - Future-Level Golden Evals

Status: complete.

Problem:

- Current golden evals cover the base brain layers, but not the new File 10 future-level routes.

Required fix:

- Added eval fixtures and metadata assertions for:
  - research opt-in
  - scenario simulation
  - proactive opt-in
  - daily focus
  - planning workspace
  - response style profile
  - long-term intelligence review
  - confirmed action preview
- Golden evals now assert layer, model profile, and key metadata flags for
  future-level routes.

Acceptance:

- Golden evals run locally without external API calls.
- Each future-level route asserts layer, model profile, and key metadata flags.

## Phase 5 - Plan Index And Status Cleanup

Status: complete.

Problem:

- The plan index still has stale wording around voice integration and undersells File 10.

Required fix:

- Updated `00_plan_index.md` so the current cursor and file descriptions match reality.
- Reworded stale status language found during this pass.
- File 10 description now includes:
  - research
  - simulation
  - proactive intelligence
  - daily focus
  - planning workspace
  - self-evaluation
  - user style profiles
  - long-term review
  - confirmed action preview

Acceptance:

- A fresh reader can understand exactly where Rex Brain stands.
- No plan file points to already-completed work as the next cursor.
