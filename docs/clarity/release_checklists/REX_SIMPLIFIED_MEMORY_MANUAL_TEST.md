# Rex Simplified Memory Manual Test

Last updated: June 4, 2026

## Purpose

Use this checklist after deploying the Phase 9 migration and restarting the Rex
backend. The goal is to prove that Rex uses the simplified direct-memory path:
one normal response, no pending memory cards, direct saves, reliable recall, and
clean corrections.

## Preconditions

- Latest `main` is deployed on the VPS.
- Supabase migrations are pushed.
- `clarity-rex.service` is restarted and `/ready` returns `ready`.
- The release build is installed on a physical phone.
- The old Memory tab shows as a saved-information view, not a pending review queue.

## Test 1: Simple Birthday Save

1. Open Assistant chat or voice.
2. Say: `My mom's birthday is June 18.`
3. Expected Rex response: natural acknowledgement, such as `Got it, your mom's birthday is June 18.`
4. Open What Rex Knows.
5. Expected: the birthday appears as saved information.
6. Expected: no pending memory card or pending review count appears.

## Test 2: Immediate Recall

1. Ask: `Do you remember my mom's birthday?`
2. Expected: Rex recalls June 18 without asking you to save anything.
3. Expected: no new duplicate memory appears.

## Test 3: Correction Updates Existing Memory

1. Say: `Actually, my mom's birthday is June 28.`
2. Expected: Rex confirms the correction naturally.
3. Open What Rex Knows.
4. Expected: the existing birthday is updated to June 28.
5. Expected: there is only one mom birthday memory.
6. Expected: no pending correction card appears.

## Test 4: Explicit Rejection

1. Say: `My favorite snack is mango.`
2. Then say: `Don't save that.`
3. Expected: Rex acknowledges the rejection.
4. Expected: the snack is not saved, or the just-saved memory is removed.

## Test 5: Commitment Still Requires Care

1. Say: `Remind me to send $200 on the 10th.`
2. Expected: Rex treats this as a commitment/action, not a memory note.
3. Expected: no memory candidate or pending memory card is created.

## Test 6: Long Voice Turn

1. Start voice mode.
2. Speak for at least 30 seconds with a continuous story.
3. Expected: Rex does not cut off too early.
4. Expected: if audio fails, the error is clear and recoverable.

## Pass Criteria

- No pending memory UI appears.
- No `/memory-candidates` call is visible in backend logs.
- Simple facts save directly.
- Recall works in the next turn.
- Corrections update instead of duplicating.
- Voice remains stable during a multi-turn conversation.
