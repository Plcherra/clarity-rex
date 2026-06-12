# step-by-step.md

## Build Order - Updated after Audit

## Phase 1: Full Dark Theme (Priority #1)

- Create one single source of truth for the dark theme.
- Update the root theme in `app.dart` to support dark mode properly.
- Apply dark theme to the main navigation shell.
- Convert all 15 screens that are still light: Dashboard, Accounts, Budgets, Transactions, Profile, Auth screens, and related flows.
- Make sure Rex and Finance finally look like the same app.

## Phase 2: Visual and Structural Unity

- Move Rex code to the correct folder structure: `/lib/rex`.
- Make Rex and financial screens use the same design system and styling.
- Fix account naming so Rex and the UI show the exact same account names.

## Phase 3: Data Truth and Backend Alignment

- Fix Rex so it never silently fails when financial context is missing.
- Fix the mismatch between actions Rex thinks it can do and what the backend actually supports.
- Improve budget logic to work consistently across months.
