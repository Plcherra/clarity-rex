# File 03 - Goals Module

Goal: make Goals feel like a purposeful planning and progress area, not a raw accountability/memory dashboard.

Working rule: Goals should show plans, milestones, commitments, progress, and next actions. Memory candidates, backend entity rows, and internal diagnostic records belong elsewhere unless explicitly transformed into goal-facing copy.

## Phase 1 - Audit Goals Data Sources And Current UI

Goal: map every record type currently feeding the Goals tab and identify what belongs in Goals versus Memory or internal diagnostics.

Files to modify / create:

- `apps/mobile/lib/rex/accountability/data/accountability_models.dart`
- `apps/mobile/lib/rex/accountability/data/accountability_api.dart`
- `apps/mobile/lib/rex/accountability/presentation/pages/accountability_page.dart`
- `services/rex-api/app/routes/accountability.py`
- `services/rex-api/app/services/accountability_service.py`
- Optional: `docs/clarity/rex_assistant_polish_plan/03_goals_module_notes.md`

Acceptance criteria:

- Plans, milestones, commitments, rules, signals, duplicate warnings, and pending memory candidates are classified.
- Records that should not render in Goals are listed.
- Current empty and loaded states are documented with known UI issues.
- No production behavior changes unless limited to docs or read-only notes.

Risks & mitigations:

- Risk: losing useful accountability data during cleanup.
- Mitigation: classify hidden data as moved to Memory, internal detail, or later admin/debug view before removing it from Goals.

Effort: Small.

## Phase 2 - Define Goals Product Contract

Goal: establish the user-facing contract for what Goals is and what it is not.

Files to modify / create:

- `apps/mobile/lib/rex/accountability/presentation/pages/accountability_page.dart`
- `apps/mobile/lib/rex/accountability/data/accountability_models.dart`
- `docs/clarity/rex_assistant_polish_plan/03_goals_module.md`

Acceptance criteria:

- Goals top-level sections are defined: Active goals, next actions, progress, completed wins, and optional signals.
- Pending memory candidates are excluded from Goals.
- Internal entity/event rows are excluded from normal Goals UI.
- Copy describes goals in user language, not backend accountability language.

Risks & mitigations:

- Risk: Goals becomes too simple and hides all intelligence.
- Mitigation: keep useful signals, but rewrite them as goal insights rather than backend records.

Effort: Small.

## Phase 3 - Rebuild Goals Overview

Goal: create a clean overview that immediately tells the user what they are working toward and what needs attention next.

Files to modify / create:

- `apps/mobile/lib/rex/accountability/presentation/pages/accountability_page.dart`
- Shared Assistant card/component files if extracted
- `apps/mobile/test/` Goals widget tests

Acceptance criteria:

- Overview shows active goal count, next action count, upcoming target count, and completed wins when available.
- Empty state invites creating or discussing a goal with Rex.
- No raw backend labels are visible.
- Widget tests cover loaded and empty overview states.

Risks & mitigations:

- Risk: adding decorative cards that reduce scanability.
- Mitigation: keep summary compact and action-oriented.

Effort: Medium.

## Phase 4 - Refine Active Goal Cards

Goal: make each active goal card show outcome, next step, progress, due date, and related milestones without exposing raw plan hierarchy.

Files to modify / create:

- `apps/mobile/lib/rex/accountability/presentation/pages/accountability_page.dart`
- `apps/mobile/lib/rex/accountability/data/accountability_models.dart`
- `apps/mobile/test/` focused goal card tests

Acceptance criteria:

- Goal cards show a clear title and user-facing description.
- Next action appears above internal milestone detail.
- Due/target dates use friendly formatting.
- Too many milestones collapse into a concise progress summary.
- Tests cover active goal with tasks, active goal with milestones only, and no-next-action state.

Risks & mitigations:

- Risk: hiding milestones users expect to see.
- Mitigation: provide expandable detail after the main next action.

Effort: Medium.

## Phase 5 - Clean Commitments And Next Actions

Goal: make commitments feel like actionable tasks, not raw memory records.

Files to modify / create:

- `apps/mobile/lib/rex/accountability/presentation/pages/accountability_page.dart`
- `apps/mobile/lib/rex/accountability/data/accountability_models.dart`
- Backend route/service only if the API lacks required fields
- Widget/model tests

Acceptance criteria:

- Open commitments render as checkable-looking next actions.
- Commitment type/status chips use human copy.
- Orphan commitments appear under Next actions, not buried in technical sections.
- Due dates and overdue states are visually clear.

Risks & mitigations:

- Risk: implying tasks are completable if no completion route exists.
- Mitigation: use view-only styling until a confirmed completion action is wired.

Effort: Medium.

## Phase 6 - Convert Signals Into Goal Insights

Goal: keep helpful accountability signals but present them as insights tied to goals or next actions.

Files to modify / create:

- `apps/mobile/lib/rex/accountability/presentation/pages/accountability_page.dart`
- `apps/mobile/lib/rex/accountability/data/accountability_models.dart`
- `services/rex-api/app/services/accountability_service.py` if signal text needs backend cleanup
- Tests for signal rendering

Acceptance criteria:

- Signals are renamed or displayed as `Insights`.
- Signal cards explain why the insight matters and what to do next.
- Severe signals are visible but not alarmist.
- Internal source refs are hidden unless transformed into human copy.

Risks & mitigations:

- Risk: losing auditability.
- Mitigation: keep source refs in debug/detail metadata, not default UI.

Effort: Medium.

## Phase 7 - Add Goal Creation Entry Points

Goal: make it obvious how to start a new goal without adding unsafe mutation behavior.

Files to modify / create:

- `apps/mobile/lib/rex/accountability/presentation/pages/accountability_page.dart`
- `apps/mobile/lib/rex/chat/presentation/pages/chat_page.dart`
- `apps/mobile/lib/rex/chat/application/chat_controller.dart`
- Backend clarity action routes only if already safe

Acceptance criteria:

- Empty Goals state has a clear `Plan with Rex` or equivalent entry.
- Existing Goals screen has a lightweight add/plan action.
- Entry opens Chat with goal-planning prompt or safe planning workspace, not an unconfirmed backend write.
- Copy clearly says Rex will help draft the goal before saving anything.

Risks & mitigations:

- Risk: users think pressing add creates a durable goal immediately.
- Mitigation: route creation through Chat/planning preview until confirmed write flow exists.

Effort: Medium.

## Phase 8 - Add Goal Detail And Progress UX

Goal: give each goal a focused detail view or expandable detail that supports progress review without cluttering the overview.

Files to modify / create:

- `apps/mobile/lib/rex/accountability/presentation/pages/accountability_page.dart`
- Optional detail page/widget under accountability presentation
- `apps/mobile/test/` detail widget tests

Acceptance criteria:

- Users can inspect milestones, commitments, completed wins, and related insights for one goal.
- Detail view uses user-facing labels and hides raw internal ids/types.
- Back navigation returns to the same Goals scroll/context.
- Tests cover opening and closing goal detail.

Risks & mitigations:

- Risk: adding navigation complexity too early.
- Mitigation: start with expandable inline detail if a full route is not justified.

Effort: Medium.

## Phase 9 - Goals Error, Loading, And Empty States

Goal: make Goals resilient when accountability data is loading, missing, partial, or degraded.

Files to modify / create:

- `apps/mobile/lib/rex/accountability/presentation/pages/accountability_page.dart`
- `apps/mobile/lib/rex/assistant_providers.dart`
- Shared Assistant state components if available from later plan files
- Widget tests

Acceptance criteria:

- Initial loading state is calm and aligned with Assistant design.
- Empty state explains that goals can be planned with Rex.
- Partial data state shows available goals while warning that some context failed.
- Retry action is visible when load fails.
- Tests cover loading, empty, error, and partial/loaded states where possible.

Risks & mitigations:

- Risk: duplicating components later standardized in File 08.
- Mitigation: keep components local/simple first, then consolidate in `08_empty_loading_error_states.md`.

Effort: Medium.

## Phase 10 - Goals Release Gate

Goal: verify Goals is ready before conversations, Deep Think, Voice, and Chat polish continue.

Files to modify / create:

- `docs/clarity/rex_assistant_polish_plan/03_goals_module.md`
- `docs/clarity/device_release_checklist.md` if manual Goals checks need updating

Acceptance criteria:

- `flutter analyze` passes.
- Goals/accountability widget tests pass.
- Relevant backend accountability tests pass if backend text/contracts changed.
- Manual phone check confirms no raw memory/entity labels, clear goal overview, useful next actions, and safe creation entry.
- Follow-up items are moved to later plan files instead of left as vague TODOs.

Risks & mitigations:

- Risk: approving Goals without realistic data.
- Mitigation: test with at least one active goal, one commitment, one milestone, one empty state, and one insight/signal.

Effort: Small.
