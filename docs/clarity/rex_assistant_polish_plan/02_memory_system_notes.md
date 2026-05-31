# File 02 - Memory System Notes

## Phase 1 Audit - Memory Surfaces And Data Contracts

Status: Complete for read-only audit. No production behavior was changed.

Purpose: identify where memory data is shown or changed before replacing backend-shaped labels with user-facing language.

## Memory Concepts

### Durable memory

Durable memory is saved long-term context stored in `long_term_memory` and exposed to the app as `MemoryItem`.

- Backend model: `services/rex-api/app/models/memory.py`
- Backend route: `GET /memory`, `PATCH /memory/{memory_id}`, `DELETE /memory/{memory_id}`
- Backend service: `SupabaseMemoryService.list_long_term_memory`, `save_long_term_memory`, `update_long_term_memory`, `deactivate_long_term_memory`
- Mobile API: `MemoryApi.getMemories`, `updateMemory`, `deactivateMemory`
- Mobile UI: `MemoryPage` under the `Notes` layer

Current durable memory fields used by the app:

- `memory_type`: `fact`, `preference`, `event`
- `content`
- `importance`
- `active`
- timestamps

### Structured memory

Structured memory is saved memory-like context in domain tables rather than `long_term_memory`.

- People: `entities` filtered to `entity_type=person`
- Rules: `personal_rules`
- Plans: `plans`
- Commitments: `commitments`
- Related events and milestones exist in the backend but are not first-class Memory tab layers today.

Mobile API methods:

- `MemoryApi.getPeople`, `updatePerson`, `deactivatePerson`
- `MemoryApi.getRules`, `updateRule`, `deactivateRule`
- `MemoryApi.getPlans`, `updatePlan`, `deactivatePlan`
- `MemoryApi.getCommitments`, `updateCommitment`, `deactivateCommitment`

Mobile UI:

- `MemoryPage` layers: `People`, `Rules`, `Plans`, `Commitments`
- `AccountabilityPage` also renders rules, commitments, plans, milestones, and duplicate warnings.

### Pending memory candidate

Pending candidates are proposed writes that require user approval before durable application.

- Backend model: `services/rex-api/app/models/memory_candidate.py`
- Backend route: `/memory-candidates`
- Backend service: `MemoryCandidateService`
- Backend extraction: `MemoryExtractionService` creates candidates after chat turns.
- Mobile domain model: `MemoryCandidateCard`
- Mobile UI: `ChatMessageBubble` renders candidate cards below assistant messages.

Supported backend candidate types:

- `long_term_memory`
- `entity`
- `entity_event`
- `personal_rule`
- `plan`
- `plan_milestone`
- `commitment`
- `correction`
- `archive`
- `merge`

Supported backend statuses:

- `pending`
- `approved`
- `rejected`
- `applied`
- `failed`

Current approval UX:

- Chat buttons do not call `/memory-candidates` directly.
- `Approve`, `Reject`, `Approve all`, and `Reject all` send natural-language commands back through Chat, such as `confirm memory candidate {id}`.
- This preserves the existing chat-driven flow, but the UI should still avoid raw backend labels.

### Correction candidate

Correction candidates are a specialized pending candidate type with `candidate_type=correction`.

- Backend service: `MemoryCorrectionService`
- Backend route for historical corrections: `GET /memory/corrections`
- Candidate approval applies corrections through `MemoryCandidateService._apply_candidate`.
- Mobile does not currently have a dedicated correction review screen.
- Correction candidates appear only as generic chat memory candidate cards today.

### Clarity action cards

Clarity action cards are separate from memory candidates but share the same chat bubble surface.

- Mobile model: `ClarityActionCard`
- Mobile UI: `ChatMessageBubble`
- Backend source: `memory_changes.clarity_action_proposals`

They should remain separate from Memory polish, except where shared label/chip components can prevent raw action/status text from leaking into the chat UI.

## User-Facing Surfaces

### Assistant Memory tab

File: `apps/mobile/lib/features/assistant/memory/presentation/pages/memory_page.dart`

Shows:

- Saved long-term memories
- People
- Rules
- Plans
- Commitments
- Active-only filter
- Type filters for long-term memories
- Edit dialogs
- Deactivate confirmations

Mutation paths:

- Edit saved memory content/type/importance/active
- Edit people/rules/plans/commitments
- Deactivate saved or structured records

Not shown today:

- Pending memory candidates
- Correction candidates
- Memory candidate history
- Search

### Chat message memory cards

Files:

- `apps/mobile/lib/features/assistant/chat/domain/chat_message.dart`
- `apps/mobile/lib/features/assistant/chat/presentation/widgets/chat_message_bubble.dart`
- `apps/mobile/lib/features/assistant/chat/application/chat_controller.dart`
- `apps/mobile/lib/features/assistant/chat/presentation/pages/chat_page.dart`

Shows:

- Candidate type
- Risk level
- Status
- Verification state
- Preview
- Expected action
- Verification message
- Approve/reject/edit controls

Mutation paths:

- Approval/rejection commands are sent as chat messages.
- Edit pre-fills the composer with `Edit pending memory {id}:`.

### Goals / Accountability tab

Files:

- `apps/mobile/lib/features/assistant/accountability/data/accountability_models.dart`
- `apps/mobile/lib/features/assistant/accountability/presentation/pages/accountability_page.dart`
- `services/rex-api/app/routes/accountability.py`

Shows:

- Signals
- Rules
- Open commitments
- Plans
- Milestones
- Duplicate warnings
- Source references

Shared dependency:

- The backend includes `pending_memory_candidates` in the accountability overview.
- The current page does not render a pending candidate section, but the overview count and models exist.
- Goals cleanup belongs in `03_goals_module.md`; this Memory phase should only document overlap.

## Raw Or Backend-Shaped Fields Currently Visible

These are the visible leaks to address in Phase 2 and later phases:

- Chat memory candidate card shows `candidate.candidateType` directly. This can display `long_term_memory`, `entity_event`, `personal_rule`, or `plan_milestone`.
- Chat memory candidate card shows `candidate.riskLevel` directly as lowercase `low`, `medium`, `high`.
- Chat memory candidate card shows `candidate.status` directly as lowercase `pending`, `applied`, `rejected`, or `failed`.
- Chat clarity action card shows `action.action.replaceAll('_', ' ')`, which removes underscores but still leaves backend action text and lowercase formatting.
- Chat clarity action card shows `action.riskLevel` and `action.status` directly.
- Memory structured people cards show `ID {shortId}`.
- Memory plan cards show `Person {shortId}`.
- Memory commitment cards show `Plan {shortId}` and `Person {shortId}`.
- Memory structured cards use generic `memoryRecordLabel`, which title-cases snake_case but does not provide stable product language for every backend value.
- Goals page has visible internal language: `Unlinked internal milestones`, `Internal milestones`, `raw records`, and `This plan has too many raw open milestones.`
- Goals source fallback uses enum names through `source.sourceType.name.accountabilityLabel`, which can produce backend-shaped text for values such as `longTermMemory`.
- Backend candidate preview builders include raw `candidate_type` prefixes, for example `entity_event: ...` or `long_term_memory: ...`; these can reach Chat and Goals if the frontend does not override them.

## Backend Contracts To Preserve

The next UI phases should preserve these existing contracts unless a phase explicitly changes them:

- `GET /memory` returns only durable `MemoryResponse` rows.
- `GET /memory/corrections` returns historical correction records, not pending correction candidates.
- `/memory-candidates` remains the canonical direct API for candidate list/create/update/approve/reject/bulk actions.
- Chat can still return candidate summaries inside `memory_changes`.
- Chat currently remains the mobile approval transport for candidate card buttons.
- Structured memory tables remain separate from `long_term_memory`.

## Phase 2 Handoff

Recommended next change: introduce shared label helpers for memory-facing enums and raw strings.

Minimum label targets:

- `long_term_memory` -> `Memory`
- `entity` -> `Person / place`
- `entity_event` -> `Related event`
- `personal_rule` -> `Rule`
- `plan` -> `Plan`
- `plan_milestone` -> `Milestone`
- `commitment` -> `Commitment`
- `correction` -> `Correction`
- `archive` -> `Archive`
- `merge` -> `Merge`
- `pending` -> `Needs review`
- `approved` -> `Approved`
- `applied` -> `Saved`
- `rejected` -> `Rejected`
- `failed` -> `Needs attention`
- `low` -> `Low risk`
- `medium` -> `Medium risk`
- `high` -> `High risk`

Phase 2 should add tests for unknown fallback behavior and verify raw snake_case labels are not rendered in Memory, Chat memory cards, or Goals.

## Phase 2 Implementation - Human Memory Labels

Status: Complete.

Implemented in:

- `apps/mobile/lib/features/assistant/memory/data/memory_models.dart`
- `apps/mobile/lib/features/assistant/chat/domain/chat_message.dart`
- `apps/mobile/lib/features/assistant/chat/presentation/widgets/chat_message_bubble.dart`
- `apps/mobile/lib/features/assistant/memory/presentation/pages/memory_page.dart`
- `apps/mobile/lib/features/assistant/accountability/data/accountability_models.dart`
- `apps/mobile/lib/features/assistant/accountability/presentation/pages/accountability_page.dart`
- `apps/mobile/test/memory_label_test.dart`

What changed:

- Added shared label helpers for memory candidate type, candidate status, risk level, generic memory record labels, and backend-prefixed candidate previews.
- Added display getters to `MemoryCandidateCard`, `ClarityActionCard`, `PendingMemoryCandidate`, and `AccountabilitySourceRef` so raw API values remain available but normal UI code uses human labels.
- Updated chat memory cards to show labels such as `Memory`, `Related event`, `Needs review`, `Saved`, and `High risk` instead of raw values such as `long_term_memory`, `entity_event`, `pending`, and `high`.
- Updated Clarity action chips to use the same readable status/risk pattern because they share the chat card surface.
- Updated Memory type filters so filters stay plural while saved memory item chips can use singular labels.
- Updated Goals/accountability fallback labels so source refs show `Memory`, `Milestone`, or `Related event` instead of enum-derived labels.
- Replaced Goals wording that exposed implementation copy: `Internal milestones`, `Unlinked internal milestones`, and `raw records`.

Verification:

- `flutter test test/memory_label_test.dart`
- `flutter analyze`

Phase 3 handoff:

- The next phase should split saved memory and pending review into distinct Memory tab sections or tabs.
- Current pending candidate review still lives only inside chat cards, and approval/rejection still travels through chat commands.

## Phase 3 Implementation - Saved Memory And Pending Review Split

Status: Complete.

Implemented in:

- `apps/mobile/lib/features/assistant/memory/data/memory_models.dart`
- `apps/mobile/lib/features/assistant/memory/data/memory_api.dart`
- `apps/mobile/lib/features/assistant/memory/application/memory_controller.dart`
- `apps/mobile/lib/features/assistant/memory/presentation/pages/memory_page.dart`
- `apps/mobile/test/memory_api_test.dart`
- `apps/mobile/test/memory_page_test.dart`

What changed:

- Added `MemoryReviewMode.saved` and `MemoryReviewMode.pending` so the Memory tab has explicit top-level modes.
- Added `PendingMemoryCandidateItem` for Memory-tab review without reusing chat bubble view state.
- Added Memory API calls for pending candidates:
  - `GET /memory-candidates?status=pending`
  - `POST /memory-candidates/{id}/approve`
  - `POST /memory-candidates/{id}/reject`
- Updated `MemoryController` to load pending candidates alongside saved memory so the Pending review count is visible from the Saved view.
- Added direct pending-candidate approve/reject handling in the Memory tab while preserving the existing Chat candidate cards and chat-command approval path.
- Added a clear Pending review header that explains Rex only saves proposed memories after approval.
- Added a separate pending-review empty state so users can distinguish no saved memory from no pending requests.
- Kept saved memory layers (`Notes`, `People`, `Rules`, `Plans`, `Commitments`) under the Saved mode.

Verification:

- `flutter test test/memory_api_test.dart test/memory_page_test.dart`

Phase 4 handoff:

- Pending candidate cards are now visible in Memory, but they are intentionally simple.
- The next phase should enrich these cards with clearer proposal/reason/source details, high-risk treatment, failed/applied/rejected state copy, and edit flow polish.

## Phase 4 Implementation - Pending Candidate Card Polish

Status: Complete.

Implemented in:

- `apps/mobile/lib/features/assistant/chat/domain/chat_message.dart`
- `apps/mobile/lib/features/assistant/chat/presentation/widgets/chat_message_bubble.dart`
- `apps/mobile/lib/features/assistant/memory/data/memory_models.dart`
- `apps/mobile/lib/features/assistant/memory/presentation/pages/memory_page.dart`
- `apps/mobile/test/chat_memory_candidate_card_test.dart`

What changed:

- Extended chat memory candidate cards with reason, source conversation/message ids, expected action labels, and stable outcome copy.
- Extended Memory pending candidate items with the same review context so Chat and Memory cards stay conceptually aligned.
- Chat candidate cards now show:
  - Proposal label and preview
  - `Why Rex suggested it` when a reason is available
  - Expected action
  - Source context such as `From recent chat`
  - Status guidance such as `Saved to Rex Memory.` or `Could not save this memory...`
- High-risk pending cards now use stronger error styling and `Confirm save` copy.
- Applied, rejected, failed, and skipped candidates have distinct status text and do not show pending approve/reject/edit controls.
- Memory pending-review cards now show reason, expected action, source context, verification messages, high-risk guidance, and a real `Edit first` flow that patches the pending candidate before approval.

Verification:

- `flutter test test/chat_memory_candidate_card_test.dart test/memory_page_test.dart`

Phase 5 handoff:

- Correction candidates now display as `Correction` and receive high-risk confirmation copy.
- The next phase should make correction-specific previews clearer by showing the old fact and replacement fact when backend payloads provide that structure.

## Phase 5 Implementation - Memory Correction Flow Clarity

Status: Complete.

Implemented in:

- `services/rex-api/app/services/memory_candidate_service.py`
- `services/rex-api/app/services/chat_service.py`
- `services/rex-api/tests/test_memory_candidate_service.py`
- `services/rex-api/tests/test_chat_service.py`
- `apps/mobile/lib/features/assistant/chat/domain/chat_message.dart`
- `apps/mobile/lib/features/assistant/chat/presentation/widgets/chat_message_bubble.dart`
- `apps/mobile/lib/features/assistant/memory/data/memory_models.dart`
- `apps/mobile/lib/features/assistant/memory/presentation/pages/memory_page.dart`
- `apps/mobile/test/chat_memory_candidate_card_test.dart`

What changed:

- Backend correction candidate previews now use old/new intent values when available, for example `correction: replace "Flowfirst" with "FlowForce"`.
- Chat service memory-correction summaries now include `old_value`, `new_value`, and `target_hint` while still returning `requires_confirmation: true` and `applied: false`.
- Correction expected action copy now says `Review correction before changing saved memory`.
- Mobile chat and Memory review models parse correction old/new/target details from direct candidate payloads, `payload_preview.intent`, or top-level correction fields.
- Chat and Memory cards now show correction-specific rows:
  - `May change: ...`
  - `Replace with: ...`
  - `Rex will wait for your approval before changing saved memory.`
- Rejecting a correction candidate is covered by backend tests and does not mutate durable memory.

Verification:

- `.venv/bin/python -m pytest tests/test_memory_candidate_service.py tests/test_chat_service.py`
- `flutter test test/memory_label_test.dart test/memory_api_test.dart test/memory_page_test.dart test/chat_memory_candidate_card_test.dart test/assistant_navigation_test.dart`
- `flutter analyze`

Phase 6 handoff:

- Correction flow is now safe and explicit, but saved memories are still organized by technical layers.
- The next phase should group saved memory into user-friendly sections such as Identity, Preferences, People & places, Plans, Rules, and Recent.

## Phase 6 Implementation - Saved Memory Grouping

Status: Complete.

Implemented in:

- `apps/mobile/lib/features/assistant/memory/data/memory_models.dart`
- `apps/mobile/lib/features/assistant/memory/application/memory_controller.dart`
- `apps/mobile/lib/features/assistant/memory/presentation/pages/memory_page.dart`
- `apps/mobile/test/memory_label_test.dart`
- `apps/mobile/test/memory_page_test.dart`
- `apps/mobile/test/assistant_navigation_test.dart`

What changed:

- Added presentation-only `MemoryGroup` labels for `Identity`, `Preferences`, `People & places`, `Plans`, `Rules`, `Recent`, and `Other memories`.
- Added `loadSavedOverview()` so the Saved Memory view loads durable memories, people, rules, plans, commitments, and the pending count together.
- Replaced the technical saved-memory layer chips with a grouped overview that hides empty groups and keeps Pending review separate.
- Grouped saved memory as:
  - facts -> `Identity`
  - preferences -> `Preferences`
  - people -> `People & places`
  - plans and commitments -> `Plans`
  - personal rules -> `Rules`
  - events -> `Recent`
- Added optional `createdAt`/`updatedAt` parsing for people, rules, plans, and commitments so saved rows can show updated dates when the backend returns them.
- Saved memory rows now show user-facing content plus type/status, importance or priority, and last updated date when available.
- Removed raw id chips from saved structured memory rows.
- Added a gentle unknown type grouping fallback through `memoryGroupForTypeLabel(...)`, covered by label tests.
- Hardened durable memory decoding so unknown `memory_type` API values map to `Other memories` instead of failing the whole Saved Memory load.

Verification:

- `flutter test test/memory_label_test.dart test/memory_api_test.dart test/memory_page_test.dart test/chat_memory_candidate_card_test.dart test/assistant_navigation_test.dart`
- `flutter analyze`

Phase 7 handoff:

- Saved memories are grouped and scannable, but finding a specific memory still requires scrolling.
- The next phase should add local search and lightweight filters across saved and pending memory without reintroducing admin-style controls.

## Phase 7 Implementation - Search And Lightweight Filters

Status: Complete.

Implemented in:

- `apps/mobile/lib/features/assistant/memory/presentation/pages/memory_page.dart`
- `apps/mobile/test/memory_page_test.dart`

What changed:

- Added a local Memory search field that filters the currently visible memory surface.
- Added quick filter chips for:
  - `Saved`
  - `Pending`
  - `Corrections`
  - `People`
  - `Preferences`
- `Saved` shows the grouped saved-memory overview.
- `Pending` shows pending memory candidates.
- `Corrections` switches to pending review and shows only correction candidates.
- `People` and `Preferences` switch to saved memory and narrow the grouped overview to those user-facing groups.
- Search matches saved memory content and metadata across facts, preferences, people, rules, plans, commitments, and recent events.
- Search also matches pending candidate preview, reason, type, risk/status labels, expected action, and correction old/new values.
- Filtered-empty state now says `No matching memories`, while true empty saved or pending states keep their original explanatory copy.
- Search text survives switching between Saved and Pending filters inside the Memory page.
- No backend query or pagination behavior changed; filtering remains presentation-only for the current loaded list.

Verification:

- `flutter test test/memory_label_test.dart test/memory_api_test.dart test/memory_page_test.dart test/chat_memory_candidate_card_test.dart test/assistant_navigation_test.dart`
- `flutter analyze`

Phase 8 handoff:

- Search and quick filtering are now in place.
- The next phase should expose safe edit/archive entry points with deliberate confirmation copy and backend route confidence checks.

## Phase 8 Implementation - Safe Edit And Archive Entry Points

Status: Complete.

Implemented in:

- `apps/mobile/lib/features/assistant/memory/data/memory_api.dart`
- `apps/mobile/lib/features/assistant/memory/application/memory_controller.dart`
- `apps/mobile/lib/features/assistant/memory/presentation/pages/memory_page.dart`
- `apps/mobile/test/memory_api_test.dart`
- `apps/mobile/test/memory_page_test.dart`

What changed:

- Kept saved-memory maintenance actions behind each row overflow menu; there are no swipe-to-archive gestures.
- Renamed the user-facing destructive action from `Deactivate` to `Archive`.
- Added archive aliases in the mobile API/controller while preserving the existing backend behavior.
- Confirmed backend route confidence: `DELETE /memory/{id}` calls `deactivate_long_term_memory(...)`, which sets `active=false` rather than hard-deleting the row.
- Archive confirmation copy now says Rex will stop using the memory in future context and that it remains in memory history.
- Structured memory rows use the same Archive copy pattern.
- Edit flow remains explicit through the overflow menu and existing edit dialogs.
- Added tests for:
  - edit payload sent to the controller/API layer
  - cancelled archive does not call the archive API
  - confirmed archive calls the archive API and removes the row from active Memory
  - mobile API archive alias using the existing safe route

Verification:

- `flutter test test/memory_label_test.dart test/memory_api_test.dart test/memory_page_test.dart test/chat_memory_candidate_card_test.dart test/assistant_navigation_test.dart`
- `flutter analyze`

Phase 9 handoff:

- Edit and archive entry points are now safer, but failures still show raw exception strings in several paths.
- The next phase should normalize user-facing failure copy and add operation-aware diagnostics without logging private memory content.

## Phase 9 Implementation - Memory Observability And Error UX

Status: Complete.

Implemented in:

- `apps/mobile/lib/features/assistant/memory/data/memory_api.dart`
- `apps/mobile/lib/features/assistant/memory/application/memory_controller.dart`
- `apps/mobile/test/memory_api_test.dart`
- `apps/mobile/test/memory_page_test.dart`
- `services/rex-api/app/routes/memory.py`
- `services/rex-api/app/routes/memory_candidates.py`
- `services/rex-api/app/services/rex_observability.py`
- `services/rex-api/tests/test_rex_brain_observability.py`

What changed:

- Mobile `MemoryApiException` now carries HTTP status codes when the backend returns an error.
- `MemoryController` maps raw errors into operation-specific user copy for load, approve, reject, edit, and archive.
- Retryable failures now use clear copy such as `Could not load Rex Memory. Check your connection and try again.`
- Non-retryable/missing-record failures now use `That memory is no longer available.`
- Raw backend details, stack-like strings, ids, and private metadata are no longer surfaced in normal Memory error copy.
- Added metadata-only `MemoryOperationObserver` for backend Memory operations.
- Memory and memory-candidate routes now log failure metadata including:
  - operation
  - memory id or candidate id when applicable
  - status code
  - safe error class
- Backend observability intentionally does not log memory content, candidate payload bodies, prompts, or user-entered text.

Verification:

- `flutter test test/memory_label_test.dart test/memory_api_test.dart test/memory_page_test.dart test/chat_memory_candidate_card_test.dart test/assistant_navigation_test.dart`
- `flutter analyze`
- `.venv/bin/python -m pytest tests/test_rex_brain_observability.py tests/test_memory_candidate_service.py tests/test_chat_service.py`
- `.venv/bin/python -m pytest tests/test_memory_routes.py tests/test_memory_candidate_routes.py`

Phase 10 handoff:

- Memory polish is now through Phase 9.
- The next phase should act as the Memory release gate: run the final automated checks, update any manual device checklist items, and record remaining Memory work explicitly instead of leaving vague follow-ups.

## Phase 10 Implementation - Memory Release Gate

Status: Automated gate complete after review fixes; manual phone validation pending.

Implemented in:

- `docs/clarity/rex_assistant_polish_plan/02_memory_system.md`
- `docs/clarity/device_release_checklist.md`

What changed:

- Added explicit Memory phone smoke checks to the device release checklist:
  - Saved Memory grouped sections
  - absence of raw backend labels
  - search and quick filters
  - pending candidate review
  - approve/reject result copy
  - Edit and Archive overflow actions
  - archive cancellation and confirmation
  - safe Memory error copy
- Added Memory failure log inspection guidance for `memory_operation_failed` logs.
- Confirmed there are no vague Memory TODOs left in `02_memory_system.md`; the only open gate is real-device validation.
- Closed review findings before phone validation:
  - pending candidate edit is now a real `PATCH /memory-candidates/{id}` path from Memory
  - Chat `Edit first` commands now update the selected pending candidate instead of only drafting text
  - unknown durable memory types decode to `Other memories`
  - parallel Memory loads use `Future.wait` so sibling load failures are observed together

Verification:

- `flutter test test/memory_label_test.dart test/memory_api_test.dart test/memory_page_test.dart test/chat_memory_candidate_card_test.dart test/assistant_navigation_test.dart`
- `flutter analyze`
- `.venv/bin/python -m pytest tests/test_memory_candidate_service.py tests/test_memory_candidate_routes.py tests/test_memory_correction_service.py tests/test_memory_routes.py tests/test_rex_brain_observability.py tests/test_chat_service.py`
- `git diff --check`

Manual phone gate still required:

- Run `./scripts/mobile_release_run.sh` with a real phone build.
- Complete the Memory-specific items in `docs/clarity/device_release_checklist.md`.
- Use at least one real pending candidate from the device or a seeded equivalent.

Handoff:

- Memory is ready for real-device release validation.
- After the phone Memory smoke test passes, continue to `03_goals_module.md` Phase 1.
