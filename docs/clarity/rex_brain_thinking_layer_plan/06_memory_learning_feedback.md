# File 06 - Memory Learning And Feedback

Goal: connect Rex Brain decisions to memory learning without letting Rex silently write risky durable memory.

Scope note: this is master phase `00.07`. It does not make new categories, budgets, or transaction learning part of personal memory. Financial category learning remains in the financial/mobile categorization pipeline; personal memory candidates only receive safe Rex Brain metadata.

## Phase 1 - Brain-Aware Memory Candidate Metadata

Attach safe Rex Brain metadata to pending memory candidates.

Acceptance:

- Correction candidates include `payload.metadata.rex_brain`.
- Extraction-created long-term/structured memory candidates include `payload.metadata.rex_brain`.
- Metadata includes layer/profile/context/model-route summaries only.
- Metadata excludes raw user text, raw financial rows, prompt text, and secrets.

Status: complete.

## Phase 2 - Manual Correction Signal

Treat user corrections as high-value learning input while keeping them confirmable.

Acceptance:

- Correction candidates remain high risk.
- Corrections require confirmation before durable writes.
- Rex Brain metadata is attached to the pending candidate, not used to bypass confirmation.

Status: complete. Existing correction confirmation behavior remains unchanged.

## Phase 3 - Financial Category Boundary

Keep financial category learning separate from personal memory learning.

Acceptance:

- Rex Brain memory metadata does not write merchant/category rules.
- Financial transaction/category feedback remains handled by the financial categorization workflow, not memory candidates.
- Rex can explain or discuss category changes, but durable category writes must still use the financial workflow.

Status: complete as a boundary/guardrail. No backend memory write path was added for financial categories.

## Phase 4 - Conversation Preference Learning

Let preference extraction keep using the memory candidate discipline path.

Acceptance:

- Preferences extracted from chat become pending candidates when appropriate.
- Rex Brain metadata helps later review show which layer produced the candidate.
- Preference extraction does not auto-apply risky or noisy memory.

Status: complete for metadata wiring; future preference-specific UI is deferred.

## Phase 5 - Bad Memory Prevention

Preserve existing discipline gates and confirmation rules.

Acceptance:

- Temporary moods, contradictions, and risky corrections remain pending/rejected according to existing memory discipline rules.
- Rex Brain metadata never downgrades risk by itself.

Status: complete.

## Phase 6 - Feedback Commands

Keep existing command routing intact.

Acceptance:

- `remember this` style turns continue through extraction/candidate creation.
- `that was wrong` style corrections continue through high-risk correction candidates.
- Approval/rejection commands keep using memory candidate decision flows.

Status: complete.

## Phase 7 - Learning Summary

Continue returning optional memory changes in chat metadata.

Acceptance:

- Chat responses still return `memory_changes` summaries.
- Candidate summaries still show confirmation-required counts.
- Rex Brain metadata stays in candidate payloads for review/debug, not in user-facing summaries by default.

Status: complete.

## Phase 8 - Memory Tests

Add and preserve tests for brain-aware memory learning.

Acceptance:

- Tests cover correction candidates receiving Rex Brain metadata.
- Tests cover extraction candidates receiving Rex Brain metadata.
- Tests assert raw private user text is not copied into Rex Brain metadata.
- Existing memory candidate, memory extraction, and chat tests pass.

Status: complete after verification.

## Phase 9 - Exit Criteria For 00.07

`00.07` is done when memory learning is brain-aware but still safe:

- Pending candidates can show which Rex Brain layer/profile produced them.
- Risky corrections remain confirmable.
- Financial category learning remains separate from personal memory.
- No new auto-write path is introduced.
- Backend memory/chat/Rex Brain tests pass.

Status: complete after verification.
