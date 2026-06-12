# File 02 - Memory System

Goal: make Rex Memory understandable, trustworthy, and safe by separating durable memories, pending candidates, corrections, and internal metadata into clear user-facing flows.

Working rule: implement one phase at a time. Memory persistence must remain safe and confirmable; no phase should silently approve, edit, delete, or merge memory records without an explicit acceptance criterion.

## Phase 1 - Audit Memory Surfaces And Data Contracts

Goal: document every Memory surface, backend route, model, and UI path that can show or mutate memories.

Status: Complete. Audit notes are captured in `02_memory_system_notes.md`.

Files to modify / create:

- `apps/mobile/lib/rex/memory/data/memory_api.dart`
- `apps/mobile/lib/rex/memory/data/memory_models.dart`
- `apps/mobile/lib/rex/memory/presentation/`
- `apps/mobile/lib/rex/chat/domain/chat_message.dart`
- `services/rex-api/app/routes/memory.py`
- `services/rex-api/app/routes/memory_candidates.py`
- Optional: `docs/clarity/rex_assistant_polish_plan/02_memory_system_notes.md`

Acceptance criteria:

- Durable memory, structured memory, pending memory candidate, correction candidate, and clarity action concepts are documented separately.
- Every user-facing place that shows memory records or candidates is listed.
- Raw backend fields currently visible to users are identified.
- No production behavior changes unless limited to docs or read-only notes.

Risks & mitigations:

- Risk: mixing Memory work with Goals cleanup.
- Mitigation: record shared dependencies but keep Goals-specific UI changes in `03_goals_module.md`.

Effort: Small.

## Phase 2 - Define Human Memory Labels

Goal: replace backend enum labels with stable human labels for memory type, candidate type, risk, and status.

Status: Complete. Human memory labels are centralized in `memory_models.dart`, wired through Chat and Goals display models, and covered by `memory_label_test.dart`.

Files to modify / create:

- `apps/mobile/lib/rex/memory/data/memory_models.dart`
- `apps/mobile/lib/rex/chat/domain/chat_message.dart`
- `apps/mobile/lib/rex/accountability/data/accountability_models.dart`
- Focused label tests

Acceptance criteria:

- `long_term_memory` displays as `Memory`.
- `entity` displays as `Person / place`.
- `entity_event` displays as `Related event`.
- `correction` displays as `Correction`.
- Raw snake_case labels are not shown in Memory, Chat memory cards, or Goals.
- Tests cover the label mapping and unknown fallback.

Risks & mitigations:

- Risk: hiding useful technical detail needed for debugging.
- Mitigation: keep raw values in debug logs/metadata, not normal UI.

Effort: Small.

## Phase 3 - Split Durable Memory From Pending Review

Goal: make the Memory tab clearly separate what Rex already knows from what Rex is asking permission to remember.

Status: Complete. Memory now has Saved and Pending review modes, with pending candidate loading, approve/reject entry points, a visible pending count, and separate empty states.

Files to modify / create:

- `apps/mobile/lib/rex/memory/presentation/`
- `apps/mobile/lib/rex/memory/data/memory_api.dart`
- `apps/mobile/lib/rex/chat/presentation/widgets/chat_message_bubble.dart`
- `apps/mobile/test/` memory-focused widget tests

Acceptance criteria:

- Durable memories have their own section or tab.
- Pending review has its own section or tab with clear copy.
- Chat memory cards still allow quick review but do not duplicate confusing full Memory UI.
- Empty states explain the difference between saved memory and pending review.

Risks & mitigations:

- Risk: users miss pending memory approvals if moved.
- Mitigation: keep a visible pending count and a direct review entry in Memory.

Effort: Medium.

## Phase 4 - Improve Pending Candidate Cards

Goal: make pending memory review cards readable, actionable, and safe.

Status: Complete. Pending candidate cards now show proposal, reason, source context, expected action, high-risk guidance, real edit-before-approval, and distinct applied/rejected/failed outcome states.

Files to modify / create:

- `apps/mobile/lib/rex/chat/presentation/widgets/chat_message_bubble.dart`
- `apps/mobile/lib/rex/memory/presentation/`
- `apps/mobile/lib/rex/chat/application/chat_controller.dart`
- `apps/mobile/test/` focused candidate-card tests

Acceptance criteria:

- Cards show: proposed memory, reason, risk, source context if available, and expected action.
- Approve, edit, and reject buttons use clear copy.
- High-risk candidates visually require extra care.
- Failed/skipped/applied candidates have distinct copy and do not look pending.
- Tests cover pending, high-risk, applied, rejected, and failed states.

Risks & mitigations:

- Risk: too much detail makes cards heavy.
- Mitigation: show the core proposal first, move metadata into expandable detail.

Effort: Medium.

## Phase 5 - Add Memory Correction Flow Clarity

Goal: make user corrections feel deliberate: Rex captures the correction, previews the affected memory, and waits for confirmation.

Status: Complete. Correction candidates now preview old/new replacement details, use safer approval copy, and are covered by backend and mobile tests that verify pending capture, approval, and rejection behavior.

Files to modify / create:

- `apps/mobile/lib/rex/chat/application/chat_controller.dart`
- `apps/mobile/lib/rex/chat/presentation/widgets/chat_message_bubble.dart`
- `services/rex-api/app/services/memory_correction_service.py`
- `services/rex-api/app/services/chat_service.py`
- Relevant backend and mobile tests

Acceptance criteria:

- Correction candidates clearly say what old fact may change and what new fact replaces it.
- Rex never says a correction was saved before approval.
- User can reject a correction without changing durable memory.
- Tests cover correction capture, preview, approval copy, and rejection copy.

Risks & mitigations:

- Risk: accidental durable memory mutation.
- Mitigation: keep correction candidates pending until explicit confirmation and assert this in tests.

Effort: Medium.

## Phase 6 - Organize Memory By Useful Groups

Goal: group saved memories in a way users can scan: Identity, Preferences, People & places, Plans, Rules, and Recent.

Status: Complete. Saved Memory now loads all saved memory surfaces into a presentation-only grouped overview with human labels, useful metadata, hidden empty groups, and an `Other memories` fallback that survives unknown durable-memory API values.

Files to modify / create:

- `apps/mobile/lib/rex/memory/data/memory_models.dart`
- `apps/mobile/lib/rex/memory/presentation/`
- `services/rex-api/app/services/memory_service.py` only if API shape blocks grouping
- Widget/model tests

Acceptance criteria:

- Memory groups use human labels.
- Empty groups are hidden unless the whole Memory tab is empty.
- Each saved memory shows content, type, confidence/importance if useful, and last updated date.
- Unknown memory types fall into a gentle `Other memories` group.

Risks & mitigations:

- Risk: grouping incorrectly implies backend truth.
- Mitigation: grouping is presentation-only unless a later backend migration explicitly changes schema.

Effort: Medium.

## Phase 7 - Add Search And Lightweight Filters

Goal: let users find memories without turning the Memory tab into an admin table.

Status: Complete. Memory now has local search and quick chips for Saved, Pending, Corrections, People, and Preferences, with filtered empty-state copy and search text preserved across Memory view switches.

Files to modify / create:

- `apps/mobile/lib/rex/memory/presentation/`
- `apps/mobile/lib/rex/memory/data/memory_api.dart`
- `apps/mobile/test/` memory UI tests

Acceptance criteria:

- Search filters saved memories and pending candidates.
- Simple chips support common filters: Saved, Pending, Corrections, People, Preferences.
- Empty filtered state says no matching memories, not no memory exists.
- Search/filter state survives simple tab switching inside Memory.

Risks & mitigations:

- Risk: local filtering diverges from backend pagination later.
- Mitigation: start with local filtering for current list size and document when server-side search is needed.

Effort: Medium.

## Phase 8 - Add Safe Edit / Archive Entry Points

Goal: expose memory maintenance actions without enabling destructive behavior by accident.

Status: Complete. Saved memory actions now expose Edit and Archive from overflow menus, archive confirmation copy explains Rex stops using the memory without implying hard deletion, and tests cover edit payloads plus cancelled and confirmed archive actions.

Files to modify / create:

- `apps/mobile/lib/rex/memory/presentation/`
- `apps/mobile/lib/rex/memory/data/memory_api.dart`
- `services/rex-api/app/routes/memory.py`
- `services/rex-api/app/services/memory_service.py`
- Backend and mobile tests where actions are wired

Acceptance criteria:

- Edit and archive are available from saved memory detail or overflow, not from accidental swipes.
- Destructive or durable changes require confirmation.
- Archive copy says the memory stops being used, not that it disappears forever.
- Tests cover edit payload, archive confirmation, and cancelled action.

Risks & mitigations:

- Risk: introducing mutation bugs late in polish.
- Mitigation: first wire UI as preview/confirmation if backend route confidence is not high.

Effort: Medium.

## Phase 9 - Memory Observability And Error UX

Goal: make memory failures understandable to users and diagnosable to developers.

Status: Complete. Memory failures now use operation-specific user copy, mobile API errors preserve HTTP status for classification, and backend memory routes log metadata-only failures with operation, ids, status code, and error class.

Files to modify / create:

- `apps/mobile/lib/rex/memory/presentation/`
- `apps/mobile/lib/rex/memory/data/memory_api.dart`
- `services/rex-api/app/routes/memory.py`
- `services/rex-api/app/routes/memory_candidates.py`
- `services/rex-api/app/services/rex_observability.py` if reused

Acceptance criteria:

- Load, approve, reject, edit, and archive failures have retryable user copy.
- Backend logs include operation, candidate/memory id, and safe error class.
- User-facing errors do not expose raw stack traces or private backend metadata.
- Tests cover at least one retryable failure and one non-retryable failure state.

Risks & mitigations:

- Risk: logging private memory content.
- Mitigation: log ids, operation names, and error classes; avoid raw memory content in logs.

Effort: Medium.

## Phase 10 - Memory Release Gate

Goal: verify Memory is ready before moving deeper into Goals and conversations polish.

Status: Automated gate complete after review fixes; manual phone validation pending. Automated mobile and backend Memory checks pass, pending edit is wired through real update paths, unknown memory types fall back safely, and the device release checklist includes explicit Memory smoke tests for labels, pending review, approve/reject/edit/archive, and safe errors.

Files to modify / create:

- `docs/clarity/rex_assistant_polish_plan/02_memory_system.md`
- `docs/clarity/device_release_checklist.md` if manual memory checks need updating

Acceptance criteria:

- `flutter analyze` passes.
- Memory model/widget tests pass.
- Relevant backend memory candidate/correction tests pass.
- Manual phone check confirms no raw memory labels, clear pending review, approve/reject/edit copy, and safe empty/error states.
- Any remaining memory work is moved to a later file instead of left as vague TODOs.

Risks & mitigations:

- Risk: approving Memory without testing real candidate data.
- Mitigation: test with at least one real pending candidate from the device or a seeded equivalent.

Effort: Small.
