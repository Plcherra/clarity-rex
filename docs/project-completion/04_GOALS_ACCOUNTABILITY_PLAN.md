# Goals And Accountability Completion Plan

## Goal

Make Goals and Accountability functional and useful for MVP so Rex can actually
help with real commitments, especially morning routine and waking up at 5 AM.

## MVP Scope

Must have:

- Create simple goals and commitments.
- View active goals and commitments in the Goals tab.
- Mark commitments as complete or archive them.
- Rex can create, track, and reference commitments with real backend confirmation.
- Morning routine accountability: wake up at 5 AM, daily check-ins, missed/completed.
- Rex and Goals tab share the exact same backend truth.

Deferred after MVP:

- Milestone trees, drag and drop, complex planning.
- Advanced analytics.
- Push notifications/reminders.
- Full accountability workflows.

## Work Plan

### Step 1: Quick Audit

- Check current backend endpoints and mobile screens.
- Identify what already works vs what is read-only.
- Completed:
  - Backend already has `/plans` and `/commitments` create/update/archive routes.
  - Rex `GoalCommandService` already writes through the same backend services.
  - Mobile Goals tab was read-only through `/accountability/overview`.

### Step 2: Make Mobile Goals Tab Functional

- Add goal and commitment creation with simple dialogs or bottom sheets.
- Add complete and archive actions.
- Refresh after backend-confirmed changes.
- In progress:
  - Mobile API methods added for plan/commitment create, complete, and archive.
  - Goals tab now has simple Add commitment / Add goal actions.
  - Commitments can be marked complete or archived.
  - Commitments can be marked missed.
  - Goals can be archived.

### Step 3: Connect Rex To The Same Data

- Rex-created commitments must appear in the Goals tab.
- UI-created commitments must be visible to Rex.
- Rex must always require backend confirmation before saying "done".
- In progress:
  - UI-created goals/commitments use the same Rex API routes as backend records
    consumed by `/accountability/overview`.
  - Rex morning accountability command now recognizes "Hold me accountable to
    wake up at 5 AM" as a habit commitment.

### Step 4: Morning Routine Focus

- Support commitments like "Wake up at 5 AM".
- Allow marking as completed or missed.
- Rex should naturally reference active commitments in conversation.
- Do not add push notifications/reminders for MVP.
- In progress:
  - Morning routine commitments are classified as habit commitments.
  - Completion and missed status are supported in UI.
  - Missed tracking remains backend signal/read-model behavior for MVP; no push
    reminders are added.

### Step 5: Tests And Verification

- Backend and mobile tests.
- Rex chat tests for goal creation and accountability.
- Manual smoke test with morning routine.

## Acceptance Criteria

- User can create a commitment in the Goals tab and Rex knows about it.
- Rex can create a commitment that appears in the Goals tab.
- Morning 5 AM commitment works.
- No fake success messages without backend confirmation.
