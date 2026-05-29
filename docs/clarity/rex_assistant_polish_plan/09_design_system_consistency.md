# File 09 - Consistency & Design System

Goal: align Assistant typography, spacing, controls, chips, cards, icons, and accessibility so Rex feels like one premium product area.

Working rule: design polish should consolidate existing patterns, not invent a separate design system that conflicts with the rest of Clarity.

## Phase 1 - Audit Assistant Visual Patterns

Goal: document the current visual inconsistencies across Assistant screens.

Files to modify / create:

- Assistant presentation files across Chat, Voice, Memory, Goals, and Chats
- Existing app theme/design files
- Optional: `docs/clarity/rex_assistant_polish_plan/09_design_system_consistency_notes.md`

Acceptance criteria:

- Typography, spacing, icon size, chips, card shape, buttons, banners, and nav states are audited.
- Repeated local styles are identified.
- Patterns that conflict with broader app design are listed.
- No production behavior changes unless limited to docs or read-only notes.

Risks & mitigations:

- Risk: subjective redesign without evidence.
- Mitigation: ground changes in repeated inconsistencies and screenshots from tested flows.

Effort: Small.

## Phase 2 - Define Assistant Design Tokens

Goal: create or document a small set of Assistant layout/style constants.

Files to modify / create:

- `apps/mobile/lib/features/assistant/presentation/assistant_design.dart` if useful
- Existing theme files if constants already belong there
- Widget tests where practical

Acceptance criteria:

- Common spacing, radii, icon sizes, chip styles, and max widths are centralized or documented.
- Constants follow existing app theme colors and text styles.
- No one-off colors are introduced without reason.
- Existing UI remains visually compatible with the rest of Clarity.

Risks & mitigations:

- Risk: token file becomes a dumping ground.
- Mitigation: add only values used by at least two Assistant surfaces.

Effort: Small.

## Phase 3 - Standardize Assistant Cards And Sections

Goal: make repeated cards and sections feel consistent without nesting cards inside cards.

Files to modify / create:

- Assistant shared presentation widgets
- Memory, Goals, Chats, and Chat card/section usages
- Widget tests

Acceptance criteria:

- Section headings use consistent typography and spacing.
- Cards use consistent border, radius, padding, and background.
- No nested card layouts are introduced.
- Dense operational views remain scan-friendly.

Risks & mitigations:

- Risk: making all surfaces too samey.
- Mitigation: keep content-specific icons and hierarchy while standardizing primitives.

Effort: Medium.

## Phase 4 - Standardize Chips And Badges

Goal: make status, risk, type, selected, and metadata chips consistent.

Files to modify / create:

- Assistant shared chip widget if useful
- Chat memory cards
- Memory review
- Goals insights/tasks
- Tests for label rendering

Acceptance criteria:

- Risk/status/type chips share size and typography.
- Selected nav chips remain distinct from metadata chips.
- Raw backend labels are never shown.
- Long chip labels wrap or truncate cleanly.

Risks & mitigations:

- Risk: chips become overused.
- Mitigation: keep chips for metadata/status only, not primary content.

Effort: Medium.

## Phase 5 - Standardize Buttons And Icon Actions

Goal: make Assistant actions predictable and accessible.

Files to modify / create:

- Assistant shared button/action widgets if useful
- Chat composer
- Voice controls
- Memory candidate actions
- Goals creation/planning actions
- Widget tests

Acceptance criteria:

- Primary, secondary, destructive, and icon-only actions have clear styles.
- Icon-only buttons have tooltips/semantic labels.
- Destructive actions require confirmation.
- Touch targets meet mobile expectations.

Risks & mitigations:

- Risk: changing button hierarchy alters workflows.
- Mitigation: preserve existing primary actions and only normalize presentation first.

Effort: Medium.

## Phase 6 - Typography And Content Density Pass

Goal: make Assistant screens easier to scan and less heavy.

Files to modify / create:

- Assistant presentation files
- Shared typography helpers only if necessary
- Manual screenshot checklist

Acceptance criteria:

- Hero-scale text is reserved for screen titles or true empty-state focus.
- Cards and rows use compact headings appropriate to their container.
- Long messages and records remain readable.
- No text overlaps or clips on iPhone SE, iPhone 13/14 class, or iPhone 16/Pro class.

Risks & mitigations:

- Risk: reducing size harms accessibility.
- Mitigation: use system text scaling checks and avoid viewport-based font scaling.

Effort: Medium.

## Phase 7 - Accessibility Semantics Pass

Goal: make Assistant screens usable with screen readers and larger text settings.

Files to modify / create:

- Assistant presentation files
- Widget tests where semantics can be asserted
- Manual checklist

Acceptance criteria:

- Nav tabs have semantic labels and selected state where practical.
- Icon actions have labels.
- Error and status changes are announced or visible to assistive tech where practical.
- Larger text does not make core controls unusable.

Risks & mitigations:

- Risk: accessibility work becomes incomplete without device testing.
- Mitigation: combine widget semantics checks with manual iOS accessibility checks.

Effort: Medium.

## Phase 8 - Design Consistency Release Gate

Goal: verify Assistant design is consistent before final release readiness.

Files to modify / create:

- `docs/clarity/rex_assistant_polish_plan/09_design_system_consistency.md`
- `docs/clarity/device_release_checklist.md`

Acceptance criteria:

- `flutter analyze` passes.
- Relevant widget tests pass.
- Manual screenshot review covers Chat, Voice, Memory, Goals, and Chats.
- Safe-area checks cover iPhone SE, iPhone 13/14 class, and iPhone 16/Pro class.
- Remaining design issues are listed with priority for File 10.

Risks & mitigations:

- Risk: visual approval without interaction testing.
- Mitigation: pair screenshot review with simple tap/scroll/type checks on each tab.

Effort: Small.
