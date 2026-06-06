# Clarity Unified Product Shell Master Plan

Status: Draft

Last updated: June 6, 2026

## Purpose

Make Clarity feel like one product instead of a finance app plus a separate Assistant/Rex mini-app.

## Core Outcome

By the end of this plan:

- The product is named Clarity across the app shell.
- Assistant is a Clarity capability.
- Rex appears only as conversational assistant personality.
- Navigation maps to user jobs, not backend modules.

## Non-Goals

- Do not implement Plaid backend.
- Do not redesign every visual detail; the design-system plan owns visual polish.
- Do not remove Rex from spoken/conversational moments where personality helps.

## Current State

| Area | Current State | Risk |
| --- | --- | --- |
| Navigation | Assistant has a nested mini-app feeling. | Product feels fragmented. |
| Naming | Clarity/Rex/Assistant labels compete. | Users may misunderstand product identity. |
| Entry points | Financial and Assistant flows are separated. | Assistant misses product context. |
| Profile/privacy | Data ownership language is scattered. | Multi-user trust is weaker. |

## Target State

| Area | Target State | Benefit |
| --- | --- | --- |
| Shell | One Clarity app shell. | Clear identity. |
| Assistant | Intelligence layer inside Clarity. | Better trust and flow. |
| Navigation | Dashboard, Accounts, Budgets, Assistant, Profile. | Simple mental model. |
| Data | Privacy/profile/settings explain one product. | Better user confidence. |

## Phase 1 - Rename Product-Level Surfaces

Goal: Apply Clarity vocabulary to product-level UI.

Files to change:

- `apps/mobile/lib/app/app.dart`
- `apps/mobile/lib/features/shell/presentation/*`
- `apps/mobile/lib/features/profile/presentation/*`

Steps:

1. Replace product-level Rex labels with Clarity/Assistant terms.
2. Keep Rex only in conversational chat/voice copy.
3. Remove backend terms from user-facing labels.
4. Add scan tests or checklist for banned terms.

Done looks like:

- Product-level UI no longer suggests Rex is a separate app.

Acceptance criteria:

- [ ] Primary shell uses Clarity/Assistant vocabulary.
- [ ] Rex remains only in conversational contexts.
- [ ] Banned label scan is documented.

## Phase 2 - Rework Bottom Navigation

Goal: Make bottom navigation represent core Clarity jobs.

Files to change:

- `apps/mobile/lib/features/shell/presentation/app_shell.dart`
- `apps/mobile/lib/features/shell/presentation/*`

Steps:

1. Keep top-level tabs focused on Dashboard, Accounts, Budgets, Assistant, Profile.
2. Remove duplicated Chat/Chats confusion from primary navigation.
3. Ensure Connect Bank is reachable from Dashboard and Accounts.
4. Ensure Assistant entry remains easy but not dominant.

Done looks like:

- Navigation is clean and product-wide.

Acceptance criteria:

- [ ] No duplicated chat tabs exist in primary shell.
- [ ] Financial setup is reachable in two taps or less.
- [ ] Existing routes still work.

## Phase 3 - Reframe Assistant As Clarity Intelligence

Goal: Make Assistant feel connected to the product, not separate.

Files to change:

- `apps/mobile/lib/features/assistant/*`
- `apps/mobile/lib/features/dashboard/presentation/*`
- `apps/mobile/lib/features/budgets/presentation/*`

Steps:

1. Add contextual Assistant entry points from financial surfaces.
2. Use screen context for starter prompts.
3. Remove copy that suggests Assistant has separate truth.
4. Keep full Assistant tab for voice/chat.

Done looks like:

- Assistant feels like Clarity's intelligence layer.

Acceptance criteria:

- [ ] Assistant entry points exist on relevant financial surfaces.
- [ ] Starter prompts reference current context.
- [ ] Assistant copy follows product vocabulary.

## Phase 4 - Reframe Accounts Around Institutions

Goal: Align product shell language around connected institutions and accounts.

Files to change:

- `apps/mobile/lib/features/accounts/presentation/*`
- `apps/mobile/lib/features/accounts/data/*`

Steps:

1. Use "Connected accounts" and "Institutions" where appropriate.
2. Treat CSV/manual accounts as secondary sources.
3. Keep account source visible but quiet.
4. Link account management to Plaid mobile plan.

Done looks like:

- Accounts reads like a modern connected-money surface.

Acceptance criteria:

- [ ] Connect Bank language is primary.
- [ ] CSV/manual language is secondary.
- [ ] Account source terminology is consistent.

## Phase 5 - Reframe Dashboard Around Daily Clarity

Goal: Make Dashboard the user's daily financial overview.

Files to change:

- `apps/mobile/lib/features/dashboard/presentation/*`
- `apps/mobile/lib/features/dashboard/data/*`

Steps:

1. Prioritize cash, spending, budgets, recent activity, and useful alerts.
2. Add Connect Bank empty state when no data exists.
3. Add Assistant insight entry where context is useful.
4. Remove CSV-first onboarding language.

Done looks like:

- Dashboard tells the user what matters today.

Acceptance criteria:

- [ ] Empty state starts with Connect Bank.
- [ ] Dashboard copy is Clarity-centered.
- [ ] Assistant entry does not feel like a separate app.

## Phase 6 - Reframe Budgets Around Guidance

Goal: Make Budgets feel like financial guidance, not just categories.

Files to change:

- `apps/mobile/lib/features/budgets/presentation/*`
- `apps/mobile/lib/features/budgets/data/*`

Steps:

1. Align budget labels with guidance and action.
2. Connect budget questions to Assistant.
3. Use synced activity as budget input.
4. Keep category mechanics quiet.

Done looks like:

- Budgets feel practical and connected to spending.

Acceptance criteria:

- [ ] Budget copy avoids backend/category jargon.
- [ ] Assistant entry can explain a budget.
- [ ] Budget state is readable at a glance.

## Phase 7 - Reframe Profile, Data, And Privacy

Goal: Make account settings explain data ownership clearly.

Files to change:

- `apps/mobile/lib/features/profile/presentation/*`
- `apps/mobile/lib/features/auth/*`

Steps:

1. Add data/privacy sections for connected banks, imports, Assistant information, and usage tracking.
2. Explain CSV fallback and Plaid disconnect at a high level.
3. Use Clarity language throughout.
4. Avoid exposing backend table names.

Done looks like:

- Users understand what Clarity stores and why.

Acceptance criteria:

- [ ] Profile has clear data/privacy navigation.
- [ ] Usage tracking is described without alarming copy.
- [ ] No backend terminology leaks.

## Phase 8 - Remove Competing Rex Labels

Goal: Clean up remaining user-facing Rex-as-product copy.

Files to change:

- `apps/mobile/lib/features/assistant/*`
- `apps/mobile/lib/features/shell/*`
- `docs/clarity/product/CLARITY_REX_LABEL_CLEANUP_LEDGER.md`

Steps:

1. Execute the cleanup ledger from prebuild.
2. Preserve conversational Rex name where allowed.
3. Rename headings/buttons to Assistant or Clarity wording.
4. Run a label scan.

Done looks like:

- Rex no longer appears as product navigation or product identity.

Acceptance criteria:

- [ ] Label scan finds no product-shell Rex violations.
- [ ] Conversational Rex usage remains natural.
- [ ] Tests/analyze pass.

## Phase 9 - Product Shell Regression Audit

Goal: Confirm the app shell behaves as one product.

Files to change:

- `docs/clarity/product/CLARITY_PRODUCT_SHELL_QA_REPORT.md`

Steps:

1. Audit main navigation on device.
2. Audit empty, loading, and connected-data states.
3. Audit product vocabulary.
4. Record remaining issues.

Done looks like:

- Product shell is ready for visual modernization and Plaid-driven flows.

Acceptance criteria:

- [ ] QA report exists.
- [ ] No critical shell/naming issue remains.
- [ ] Flutter analyze passes.

## Verification Commands

```bash
rg -n "Rex|rex|pending|candidate|review" apps/mobile/lib
cd apps/mobile && flutter analyze
cd apps/mobile && flutter test test
```

## Execution Order

1. Phase 1 - Rename Product-Level Surfaces
2. Phase 2 - Rework Bottom Navigation
3. Phase 3 - Reframe Assistant As Clarity Intelligence
4. Phase 4 - Reframe Accounts Around Institutions
5. Phase 5 - Reframe Dashboard Around Daily Clarity
6. Phase 6 - Reframe Budgets Around Guidance
7. Phase 7 - Reframe Profile, Data, And Privacy
8. Phase 8 - Remove Competing Rex Labels
9. Phase 9 - Product Shell Regression Audit

## Release Gate

This plan is complete when Clarity reads as one product across shell, navigation, copy, and data/privacy surfaces.
