#5 Clarity Design System

Status: Draft

Last updated: June 6, 2026

## Purpose

Replace the heavy, primitive, mixed-theme UI with a modern app-wide dark minimal design system inspired by the Clarity logo.

## Core Outcome

By the end of this plan:

- Dark/minimal theme applies across the full app.
- Rex-only tokens are replaced by app-wide Clarity tokens.
- UI uses less color, lighter borders, calmer surfaces, and better hierarchy.
- Financial green/red are reserved for money states.

## Non-Goals

- Do not implement Plaid behavior.
- Do not change financial business logic.
- Do not create decorative marketing layouts inside operational screens.

## Current State

| Area | Current State | Risk |
| --- | --- | --- |
| Theme | Global app is light; Assistant has separate dark tokens. | App feels inconsistent. |
| Visual weight | Borders, pills, cards, and typography are heavy. | UI feels primitive and crowded. |
| Color | Olive/yellow dominates Assistant. | Brand does not match logo direction. |
| QA | No app-wide screenshot gate. | Regressions slip through. |

## Target State

| Area | Target State | Benefit |
| --- | --- | --- |
| Palette | Near-black blue base with restrained teal accent. | Modern and brand-aligned. |
| Components | Minimal cards, quiet borders, compact controls. | Cleaner daily use. |
| Typography | Consistent scale and readable hierarchy. | Less visual fatigue. |
| QA | Screenshot/accessibility pass on major screens. | Safer release. |

## Phase 1 - Current Color Usage Audit

Goal: Measure current color, token, and theme drift before defining the new palette.

Files to change:

- `docs/clarity/product/CLARITY_COLOR_USAGE_AUDIT.md`
- `docs/clarity/product/CLARITY_DESIGN_TOKEN_CONTRACT.md`

Steps:

1. Scan Flutter code for hard-coded colors, Rex-only tokens, light-theme assumptions, and olive/yellow dominance.
2. Group findings by app shell, Dashboard, Accounts, Budgets, Assistant, What Clarity Knows, and Profile.
3. Mark colors to keep, replace, or reserve only for financial states.
4. Create a short removal checklist for the design phases.

Done looks like:

- The design system starts from evidence, not guesswork.

Acceptance criteria:

- [ ] Audit lists current hard-coded colors and feature-specific token sources.
- [ ] Audit identifies Rex-only theme drift.
- [ ] Audit identifies colors that must be reserved for money states or removed.

## Phase 2 - Extract Logo Palette

Goal: Derive the app color direction from the Clarity logo.

Files to change:

- `docs/clarity/product/CLARITY_DESIGN_TOKEN_CONTRACT.md`
- `apps/mobile/lib/app/app.dart`

Steps:

1. Sample logo-inspired near-black, teal, text, muted text, border, and surface colors.
2. Define positive/negative money colors separately.
3. Document accent usage limits.
4. Avoid olive/yellow as the dominant app theme.

Done looks like:

- Palette is clear before implementation.

Acceptance criteria:

- [ ] Token contract lists app colors and usage rules.
- [ ] Financial green/red are reserved for money states.
- [ ] Accent color is not overused.

## Phase 3 - Define Dark App Tokens

Goal: Add app-wide token source for color, spacing, radius, typography, and motion.

Files to change:

- `apps/mobile/lib/app/clarity_theme.dart`
- `apps/mobile/lib/app/app.dart`

Steps:

1. Create app-wide tokens.
2. Define base/surface/elevated/input/border/text/accent/danger/success colors.
3. Define spacing and radius scale.
4. Define typography scale without viewport-based font sizing.

Done looks like:

- UI can reference one Clarity token system.

Acceptance criteria:

- [ ] Tokens are app-wide, not feature-specific.
- [ ] Theme file remains under 300 lines.
- [ ] Flutter analyze passes.

## Phase 4 - Replace Rex-Only Tokens

Goal: Remove Assistant-only theme drift.

Files to change:

- `apps/mobile/lib/features/assistant/presentation/rex_ui_tokens.dart`
- `apps/mobile/lib/features/assistant/**/*`
- `apps/mobile/lib/app/clarity_theme.dart`

Steps:

1. Replace Rex UI token references with Clarity tokens.
2. Keep Assistant personality in copy, not theme.
3. Remove duplicate color definitions.
4. Keep assistant-specific layout helpers only where needed.

Done looks like:

- Assistant uses the same app design system.

Acceptance criteria:

- [ ] No active Rex-only color palette remains.
- [ ] Assistant visual style matches app shell.
- [ ] Flutter analyze passes.

## Phase 5 - Modernize Typography Scale

Goal: Make text hierarchy cleaner and less bulky.

Files to change:

- `apps/mobile/lib/app/clarity_theme.dart`
- `apps/mobile/lib/features/*/presentation/*`

Steps:

1. Define readable title/body/caption styles.
2. Reduce oversized headings inside dense product screens.
3. Ensure chat bubbles and cards use appropriate body sizes.
4. Keep letter spacing at 0 unless required by existing font behavior.

Done looks like:

- Text feels modern, calm, and scannable.

Acceptance criteria:

- [ ] No viewport-scaled font sizes are introduced.
- [ ] Dense screens do not use hero-scale text.
- [ ] Accessibility text remains readable.

## Phase 6 - Modernize Spacing And Radius

Goal: Normalize app layout spacing and component shape.

Files to change:

- `apps/mobile/lib/app/clarity_theme.dart`
- `apps/mobile/lib/shared/widgets/*`
- `apps/mobile/lib/features/*/presentation/*`

Steps:

1. Define spacing scale.
2. Reduce excessive pill/card rounding.
3. Use stable dimensions for nav, toolbars, chips, and inputs.
4. Avoid nested cards.

Done looks like:

- UI breathes without feeling inflated.

Acceptance criteria:

- [ ] Repeated components use shared spacing/radius.
- [ ] Cards are not nested inside cards.
- [ ] Fixed-format controls have stable dimensions.

## Phase 7 - Simplify Cards, Pills, And Borders

Goal: Reduce visual heaviness.

Files to change:

- `apps/mobile/lib/shared/widgets/*`
- `apps/mobile/lib/features/dashboard/presentation/*`
- `apps/mobile/lib/features/accounts/presentation/*`
- `apps/mobile/lib/features/assistant/presentation/*`

Steps:

1. Replace heavy bordered panels with quiet surfaces.
2. Reduce thick outlines and oversized chips.
3. Use dividers and whitespace where clearer.
4. Keep cards for repeated items and framed tools only.

Done looks like:

- Screens feel modern and less crowded.

Acceptance criteria:

- [ ] No page sections styled as unnecessary floating cards.
- [ ] Repeated item cards remain readable.
- [ ] Screenshot QA shows reduced visual weight.

## Phase 8 - Define Financial State Colors

Goal: Make financial colors meaningful and restrained.

Files to change:

- `apps/mobile/lib/app/clarity_theme.dart`
- `apps/mobile/lib/features/finance/*`
- `apps/mobile/lib/features/dashboard/*`

Steps:

1. Define positive, negative, warning, and neutral money colors.
2. Apply colors only to financial state, not generic decoration.
3. Ensure contrast in dark mode.
4. Add examples to token contract.

Done looks like:

- Green/red communicate money state clearly.

Acceptance criteria:

- [ ] Money colors are not used as generic UI accents.
- [ ] Positive/negative values are accessible.
- [ ] Financial screens are calm and scannable.

## Phase 9 - Apply Base Theme Globally

Goal: Convert app shell and major screens to the Clarity dark theme.

Files to change:

- `apps/mobile/lib/app/app.dart`
- `apps/mobile/lib/features/shell/*`
- `apps/mobile/lib/features/dashboard/*`
- `apps/mobile/lib/features/accounts/*`
- `apps/mobile/lib/features/budgets/*`
- `apps/mobile/lib/features/assistant/*`
- `apps/mobile/lib/features/profile/*`

Steps:

1. Apply app-wide dark theme.
2. Remove local light-theme assumptions.
3. Ensure bottom navigation is dark/minimal.
4. Fix status bar/system UI colors.

Done looks like:

- Clarity is dark/minimal everywhere.

Acceptance criteria:

- [ ] No major surface falls back to light theme.
- [ ] Bottom navigation matches app theme.
- [ ] Flutter analyze passes.

## Phase 10 - Visual QA, Accessibility, And Screenshot Pass

Goal: Ensure the modern minimal UI is readable, accessible, and visually consistent across devices.

Files to change:

- `docs/clarity/product/CLARITY_ACCESSIBILITY_QA_REPORT.md`
- `docs/clarity/product/CLARITY_VISUAL_QA_REPORT.md`
- `apps/mobile/lib/app/clarity_theme.dart`

Steps:

1. Check contrast for text, buttons, chips, inputs, and financial values.
2. Fix muted text that is too dim.
3. Verify tap target sizes.
4. Capture Dashboard, Accounts, Budgets, Assistant Chat, Voice, What Clarity Knows, and Profile.
5. Test at least small and large iPhone viewports.
6. Check overlaps, clipped text, excessive weight, and inconsistent color.
7. Document remaining exceptions and risks.

Done looks like:

- Minimal does not become hard to read, and UI is ready for product-level manual testing.

Acceptance criteria:

- [ ] Primary and secondary text contrast passes.
- [ ] Tap targets remain usable.
- [ ] QA report records tested screens.
- [ ] Screenshot QA report exists.
- [ ] No text overlap/clipping in primary flows.
- [ ] Visual style is consistent across major screens.

## Verification Commands

```bash
cd apps/mobile && flutter analyze
cd apps/mobile && flutter test test
rg -n "RexUiTokens|0xFF746A05|0xFFE5CD6A|Colors\\.white|Colors\\.black|Color\\(" apps/mobile/lib
```

## Execution Order

1. `CLARITY_PREBUILD_FOUNDATION_MASTER_PLAN.md`
2. `CLARITY_USAGE_TRACKING_SIMPLIFIED_PLAN.md`
3. `PLAID_BACKEND_CORE_MASTER_PLAN.md`
4. `PLAID_MOBILE_AND_ACCOUNT_CONNECTION_MASTER_PLAN.md`
5. `CLARITY_DESIGN_SYSTEM_MASTER_PLAN.md`
6. `CLARITY_UNIFIED_PRODUCT_SHELL_MASTER_PLAN.md`
7. `CLARITY_FINANCIAL_EXPERIENCE_MASTER_PLAN.md`
8. `CLARITY_ASSISTANT_INTELLIGENCE_MASTER_PLAN.md`
9. `CLARITY_RELEASE_VALIDATION_MASTER_PLAN.md`

## Release Gate

This plan is complete only when the whole app looks like one modern dark Clarity product, not a patched Assistant theme.
