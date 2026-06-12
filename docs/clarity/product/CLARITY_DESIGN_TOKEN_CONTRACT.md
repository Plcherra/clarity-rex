# Clarity Design Token Contract

Status: Phase 5 prebuild contract  
Last updated: 2026-06-06  
Owner: Clarity mobile product architecture

## Executive Summary

Clarity uses one app-wide visual system. The Assistant, financial screens, profile, onboarding, and future Plaid flows must all consume the same design tokens.

The direction is modern, dark, minimal, and calm:

- Near-black blue foundation inspired by the logo background.
- Restrained teal accent inspired by the logo mark.
- Off-white text with muted secondary text.
- Green and red only for financial states.
- Light borders, low elevation, compact spacing, and clear hierarchy.

There must be no separate Rex-only theme. Rex is the Assistant personality, not a second product or visual system.

## Current Drift To Remove

These are the known visual splits the later UI phases must collapse:

- `apps/mobile/lib/app/app.dart` still defines a light beige global app theme.
- `apps/mobile/lib/rex/presentation/rex_ui_tokens.dart` defines Assistant-only tokens.
- `apps/mobile/lib/rex/presentation/rex_surfaces.dart` builds Assistant-only surfaces.
- Financial screens still use many hardcoded light colors, large radii, and repeated border rules.
- Assistant screens already use dark UI, but it is heavier than the final Clarity target.

The final token source should live under app or core theme ownership, not under the Assistant feature.

Target implementation path:

- `apps/mobile/lib/core/theme/clarity_tokens.dart`
- `apps/mobile/lib/core/theme/clarity_theme.dart`
- `apps/mobile/lib/app/app.dart`

`RexUiTokens` may remain only as a temporary adapter during migration. It must not be the final app token source.

## Color Tokens

| Token | Value | Usage |
| --- | --- | --- |
| `clarity.color.bg.base` | `#050A0D` | Primary app background. |
| `clarity.color.bg.layer` | `#081116` | App shell, bottom bars, major bands. |
| `clarity.color.surface.1` | `#0D1517` | Cards, chat bubbles, sheets. |
| `clarity.color.surface.2` | `#121C1E` | Raised or selected surfaces. |
| `clarity.color.surface.hover` | `#182325` | Pressed, focused, or active states. |
| `clarity.color.border.subtle` | `#263232` | Default borders and dividers. |
| `clarity.color.border.strong` | `#364542` | Focused controls and important separators. |
| `clarity.color.text.primary` | `#F4F1EA` | Primary text. |
| `clarity.color.text.secondary` | `#B9B2A6` | Secondary labels and descriptions. |
| `clarity.color.text.muted` | `#80796F` | Metadata, timestamps, placeholders. |
| `clarity.color.accent.teal` | `#1F9A82` | Primary brand accent, sparingly. |
| `clarity.color.accent.teal.soft` | `#123A35` | Subtle selected states and icon wells. |
| `clarity.color.accent.gold` | `#E7D66B` | Rare highlight for Assistant identity or active affordances. |
| `clarity.color.money.positive` | `#35C477` | Positive balances, income, budget remaining. |
| `clarity.color.money.negative` | `#F05F63` | Spending over budget, debt, negative balances. |
| `clarity.color.state.warning` | `#E6B85C` | Non-money warnings and attention states. |
| `clarity.color.state.danger` | `#F26D6D` | Errors, destructive actions, failed sync. |

## Color Usage Rules

- Use `clarity.color.bg.base` for the app canvas. Do not use beige or pure black as the default canvas.
- Use teal as an accent, not as a dominant wash across the app.
- Use gold rarely. It may identify Assistant moments, active tab state, or a subtle premium highlight, but it must not dominate full screens.
- Use green and red only when the color communicates money state or destructive action.
- Do not use color alone to communicate financial meaning. Pair it with labels, signs, or icons.
- Avoid one-note palettes. A screen should not read as all olive, all yellow, all teal, or all slate.

## Typography Tokens

| Token | Size | Weight | Usage |
| --- | ---: | ---: | --- |
| `clarity.type.display` | 32 | 700 | Top-level screen title only. |
| `clarity.type.title` | 24 | 700 | Major section or page area. |
| `clarity.type.section` | 18 | 700 | Section headers. |
| `clarity.type.body` | 16 | 500 | Primary readable body text. |
| `clarity.type.bodyStrong` | 16 | 700 | Important values and labels. |
| `clarity.type.label` | 14 | 600 | Controls, chips, field labels. |
| `clarity.type.meta` | 12 | 500 | Metadata and compact status text. |

Typography rules:

- Letter spacing is always `0`.
- Do not scale font size with viewport width.
- Use display text only for true screen titles, not cards, bubbles, or dashboard widgets.
- Chat and voice transcripts should be readable but not oversized.
- Financial screens should be dense, calm, and scannable.

## Spacing Tokens

| Token | Value |
| --- | ---: |
| `clarity.space.1` | 4 |
| `clarity.space.2` | 8 |
| `clarity.space.3` | 12 |
| `clarity.space.4` | 16 |
| `clarity.space.5` | 20 |
| `clarity.space.6` | 24 |
| `clarity.space.8` | 32 |
| `clarity.space.10` | 40 |

Spacing rules:

- Default page horizontal padding is `clarity.space.5` or `clarity.space.6`.
- Dense financial lists may use `clarity.space.4`.
- Avoid stacked oversized vertical gaps.
- Use stable dimensions for fixed-format elements like nav bars, icon buttons, account rows, and budget rows.

## Radius Tokens

| Token | Value | Usage |
| --- | ---: | --- |
| `clarity.radius.xs` | 4 | Tiny indicators and progress marks. |
| `clarity.radius.sm` | 6 | Small chips and compact inputs. |
| `clarity.radius.md` | 8 | Default cards, rows, repeated items. |
| `clarity.radius.lg` | 12 | Search fields, chat bubbles, sheets. |
| `clarity.radius.full` | 999 | Circular icon buttons and avatars only. |

Radius rules:

- Default cards must use `clarity.radius.md`.
- Do not use pill shapes for large content cards.
- Large radius is allowed for chat bubbles and primary input surfaces only.
- Nested cards are not allowed.

## Border And Elevation Tokens

| Token | Value | Usage |
| --- | --- | --- |
| `clarity.border.none` | `0` | Plain full-width sections. |
| `clarity.border.hairline` | `1px #263232` | Default surface boundary. |
| `clarity.border.focus` | `1px #1F9A82` | Keyboard focus, selected input. |
| `clarity.elevation.none` | none | Default. |
| `clarity.elevation.low` | subtle shadow, max 12 blur | Floating input bar or modal only. |

Border and elevation rules:

- Prefer surface contrast and hairline borders over heavy outlines.
- Avoid thick decorative borders.
- Avoid stacked shadows.
- Cards should not feel inflated or chunky.

## Component Rules

Navigation:

- Bottom navigation is Clarity-wide, not Assistant-specific.
- Active states use soft teal or soft gold, never large bright pills.
- Icons should remain familiar and stable.

Cards:

- Cards are for repeated items, modals, and framed tools.
- Page sections should be full-width bands or unframed layouts, not cards inside cards.
- Financial cards should prioritize numbers, trend, and action.

Buttons:

- Primary actions use teal or neutral filled surfaces.
- Destructive actions use danger.
- Icon buttons use recognizable symbols and tooltips where needed.
- Avoid text-heavy rounded rectangles where an icon control is standard.

Inputs:

- Inputs use dark surfaces, subtle borders, and clear focus rings.
- Placeholder text uses muted text.
- Text must never be clipped or overlap controls.

Assistant:

- Assistant surfaces use the same Clarity tokens.
- Assistant can have personality through copy, motion, and voice, not a separate theme.
- The chat input should be simple, compact, and stable.

Finance:

- Money values must be clear, aligned, and easy to compare.
- Positive and negative states use financial colors only where meaning is necessary.
- Do not make financial pages decorative or marketing-like.

## Accessibility Targets

- Body text contrast must meet WCAG AA 4.5:1.
- Large text and icon contrast must meet at least 3:1.
- Interactive targets should be at least 44 x 44 logical pixels.
- Focus states must be visible in dark mode.
- Dynamic text must not overlap or escape controls.
- Important color states must have a non-color cue.

## Banned Patterns

- Separate Rex-only app theming.
- Beige/light theme as the default app shell.
- Olive/yellow dominance across full screens.
- Heavy borders around every element.
- Oversized pill controls for major content.
- Nested cards.
- Decorative blobs, orbs, or bokeh backgrounds.
- Gradient-first screens where content clarity is the goal.
- Hardcoded feature colors when a Clarity token exists.

## Acceptance Checklist

- [x] Contract includes token names and usage rules.
- [x] Contract explicitly bans separate Rex-only app theming.
- [x] Contract includes accessibility contrast targets.
- [x] Contract defines financial green/red as meaning-only colors.
- [x] Contract identifies current token drift to remove.
- [x] Contract names the future app-wide token ownership path.
