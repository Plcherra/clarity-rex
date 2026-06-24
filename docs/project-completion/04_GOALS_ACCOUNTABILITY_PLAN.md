# Goals And Accountability Completion Plan

## Goal

Turn Goals from a mostly read-only accountability overview into a complete user-facing system for plans, milestones, commitments, rules, progress, and Rex follow-through.

## Current State

- Backend supports plans, plan milestones, commitments, personal rules, entity links, and accountability signals.
- Mobile Goals tab calls `/accountability/overview`.
- Mobile can display signals, active rules, commitments, plans, milestones, completed milestones, and duplicate warnings.
- Direct create/edit/complete flows for goals are incomplete or not surfaced in the Goals UI.

## Work Plan

### 1. Define Goals Product Model

Use a clear hierarchy:

- Plan: the larger outcome.
- Milestone: a checkpoint inside a plan.
- Commitment: an action or promise.
- Rule: an ongoing personal standard.
- Accountability signal: Rex-generated warning or insight.

### 2. Goals UI Actions

Add user-facing actions:

- Create plan.
- Edit plan.
- Archive plan.
- Create milestone.
- Mark milestone complete.
- Create commitment.
- Mark commitment complete.
- Archive commitment.
- Create/edit/archive rule.
- Ask Rex about a signal.

### 3. Backend Route Usage

Wire mobile clients for routes already present:

- `POST /plans`
- `PATCH /plans/{plan_id}`
- `DELETE /plans/{plan_id}`
- `GET /plans/{plan_id}/milestones`
- `POST /plans/{plan_id}/milestones`
- `PATCH /plans/milestones/{milestone_id}`
- `DELETE /plans/milestones/{milestone_id}`
- `POST /commitments`
- `PATCH /commitments/{commitment_id}`
- `DELETE /commitments/{commitment_id}`
- `POST /rules`
- `PATCH /rules/{rule_id}`
- `DELETE /rules/{rule_id}`

Keep backend confirmation before success UI.

### 4. Rex Goal Commands

- Ensure Rex-created goals and UI-created goals share the same backend records.
- Avoid separate goal systems.
- Rex should confirm only after backend writes.
- Rex should ask clarification when a goal or commitment is ambiguous.

### 5. Accountability Signals

- Keep `/accountability/overview` for the default Goals tab.
- Add drill-down routes only if the UI needs them:
  - `/accountability/signals`
  - `/accountability/rule-risks`
  - `/accountability/plan-risks`
  - `/accountability/patterns`
- Add dismiss/resolve only if backend supports durable status changes.

### 6. Duplicate And Drift Handling

- Show duplicate warnings clearly.
- Let user merge, ignore, or archive duplicates only after backend supports it.
- Avoid automatic merge without confirmation.

## Acceptance Criteria

- User can create, edit, complete, and archive core goal records.
- Rex and Goals tab show the same records.
- Goals tab is useful even with zero records.
- Accountability signals have clear source labels.
- Duplicate warnings do not block normal goal use.

## Suggested Tests

- Backend:
  - plan service tests
  - goal command service tests
  - accountability service tests
  - route tests for plans, commitments, and rules
- Flutter:
  - accountability controller tests
  - Goals page widget tests
  - create/edit/complete flow tests

## Manual Smoke

1. Create a plan in UI.
2. Add milestone.
3. Add commitment.
4. Ask Rex about the plan.
5. Complete the milestone.
6. Confirm Goals overview updates.
7. Ask Rex what commitments are still open.
8. Archive the plan and confirm it no longer appears active.
