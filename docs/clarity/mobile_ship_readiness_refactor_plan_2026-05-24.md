# Mobile Ship Readiness Refactor Plan - 2026-05-24

This plan captures the current real situation after the transaction/category refactor and the latest phone testing. The goal is to make Clarity feel stable, coherent, and ready to ship without hiding broken logic behind more UI.

## Current Situation

- Voice works on the stable cloud-turn path. The old `--dart-define=REX_NATIVE_IOS_VOICE_ENABLED=true` flag is ignored so copied release commands cannot switch into the unfinished native bridge by accident.
- Voice calls are treated as a separate call screen. They can pass the active `conversationId`, but the user experience feels disconnected because voice replies are shown in the call page instead of living inside the current chat thread.
- The Assistant conversations button is visually detached from Chat, Voice, Memory, and Goals.
- Dashboard values can temporarily show `$0.00` after app restart/logout/login while data is still loading or while the dashboard snapshot is built before the financial read model has populated the full transaction/account context.
- Account health currently uses a runway/burn-rate card. For accounts with no positive balance, it produces a technically correct but unhelpful message.
- Accounts has two add-account controls when accounts exist: the top `+` and a bottom floating `+`. The bottom one collides conceptually and spatially with the global sign-out action.
- The UI is functional but heavy: many large cards, repeated borders, oversized empty space, and mixed navigation patterns make the app feel more prototype than polished finance product.

## Phase 1 - Stabilize The Current Tested Path

Goal: keep the working voice path working and remove confusing UI artifacts.

- Do not use native iOS voice flags for release builds.
- Remove the `Listening to you...` placeholder bubble from the call page.
- Keep live transcript only when real text exists.
- Align the conversations control with the Assistant tab controls.
- Remove the bottom add-account floating button and keep the top `+`.

Done criteria:

- `flutter run -d 00008150-000C03C83A2B401C --release --dart-define=REX_BACKEND_URL=https://api.goclarity.app` works for voice.
- The release command does not include native iOS voice flags.
- Assistant header and account add/sign-out controls no longer feel detached or overlapping.

## Phase 2 - Move Voice Into Chat

Status: first implementation complete.

Goal: voice should be another input mode for the current Rex conversation, not a separate destination.

- Replace the Voice tab call-screen-first experience with an in-chat voice mode.
- The phone button in the chat composer should start a compact active-call panel inside `ChatPage`.
- Voice should use the currently loaded chat `conversationId`.
- User transcripts and Rex responses should append to the same chat timeline as normal messages.
- The call panel should show only state and controls: listening, thinking, speaking, mute/end.
- Keep the full-screen `VoiceCallPage` only as an optional fallback/debug route until the new flow is proven.

Implemented:

- Chat composer phone button starts the existing `voiceCallProvider` inline.
- The call no longer pushes `VoiceCallPage` from `ChatPage`.
- A compact in-chat call panel shows voice status, live transcript/error, mute, interrupt, retry/settings, and end.
- Voice starts with the current `chatProvider.conversationId`, so previously opened conversations continue through voice.
- Completed voice turns still flow through `chatProvider.applyBackendMessages`, keeping transcripts and Rex replies in the chat timeline.
- The Assistant Voice tab no longer embeds the full-screen call page.

Done criteria:

- Opening a previous conversation and pressing voice continues that same conversation.
- Voice transcript and Rex reply appear in the chat thread immediately after each turn.
- Ending a call leaves the user in the same chat.

## Phase 3 - Disable Or Finish Native iOS Voice

Status: implemented as an experimental-only gate.

Goal: prevent a release flag from enabling a broken path.

- The public `REX_NATIVE_IOS_VOICE_ENABLED` launch path is ignored.
- Native iOS voice can only be requested with `REX_EXPERIMENTAL_NATIVE_IOS_VOICE_ENABLED=true`.
- The app logs a runtime warning when the legacy flag is present.
- The app logs a fallback warning when the experimental native bridge is requested but unavailable.
- If we decide to finish native voice, define a separate project plan for the iOS bridge, event stream, background audio session, and error recovery.

Done criteria:

- A developer cannot accidentally ship the broken native voice path by copying a test command.
- Stable cloud-turn voice remains the default.

## Phase 4 - Fix Dashboard Startup Truth

Status: first implementation complete.

Goal: dashboard should not show `$0.00` as if it were real data when transactions exist.

- Add explicit dashboard loading/skeleton state for financial snapshot loads.
- Do not render cash-flow metric cards with zero values until the financial read model has loaded or there is a true empty state.
- Verify `FinancialReadModelService.load()` is called after auth restoration and after import completion.
- Ensure `DashboardRefreshCoordinator.refreshAllState()` updates all visible dashboard/account scopes after import and after app resume.
- Add tests for app restart/auth restore with existing accounts and transactions.

Implemented:

- Dashboard snapshot and budget performance now come from one `FinancialReadModel` load through `DashboardUiController.dashboardViewDataForScope`.
- Dashboard render state now distinguishes loading, true empty data, and imported-statements-still-resolving data.
- Loading clears stale dashboard data instead of keeping previous or false-zero cards visible.
- Account and global dashboard scopes both use the same dashboard view-data contract.
- Statement imports can now be scoped by dashboard scope, with a regression test covering global, account, and missing-account cases.

Done criteria:

- After closing/reopening the app, the dashboard either shows a loading state or the correct values, never false `$0.00` values.
- Import completion updates dashboard values without leaving stale cards behind.

## Phase 5 - Replace Account Health

Status: first implementation complete.

Goal: account health should be useful even when balance is zero, missing, or statement-based.

- Replace the current runway-only card with a health summary based on available facts:
  - latest statement balance
  - income vs spend this month
  - top current-month spend pressure
  - missing statement balance warning
  - budget coverage when budgets exist
- Use neutral copy when balance is unavailable instead of telling the user runway cannot be estimated.

Implemented:

- Replaced the runway-only burn-rate card with an account health summary.
- The card now reports statement balance status, monthly cash flow, biggest spend pressure, and budget coverage.
- Missing statement balance is shown as a data-quality warning, not a failed health formula.
- The old "With no positive balance..." message was removed from app code.

Done criteria:

- No account with transactions shows the current unhelpful "With no positive balance..." message as the main health result.
- The card gives a next useful action, not just a formula failure.

## Phase 6 - Dashboard Information Architecture

Status: first implementation complete.

Goal: make the dashboard feel like a finance product instead of a stack of large isolated cards.

- Compress cash-flow cards into one summary section: Available, Income, Spending, Net.
- Move "Biggest leaks" closer to spending context.
- Reduce repeated card borders and vertical gaps.
- Make transactions controls sticky or visually grouped so they do not feel buried.
- Keep transaction rows dense enough for repeated use.

Implemented:

- Replaced the separate giant cash-flow and spending metric cards with one compact cash-flow summary.
- The summary now shows available statement balance, income, spending, and net in one module.
- Moved biggest leaks directly under the summary as `Spending pressure`.
- Reduced the main dashboard section gap and removed the unused oversized metric card widget.

Done criteria:

- First viewport shows meaningful financial status plus next action.
- The dashboard can be scanned without excessive scrolling.

## Phase 7 - Assistant Navigation Polish

Status: first implementation complete.

Goal: Assistant controls should look like one coherent navigation system.

- Decide whether Conversations is a fifth tab, a segmented action next to Chat, or a title-bar action.
- Use one consistent size, radius, icon weight, and selected state.
- Avoid placing an icon in the status-bar danger zone or making it look detached from the tab row.

Implemented:

- Conversations is now a fifth Assistant tab (`Chats`) instead of a detached top-right button.
- Chat, Voice, Memory, Goals, and Chats now share one TabBar treatment, selected state, and safe-area position.
- The conversation list can render embedded inside Assistant without its own app bar.
- Opening or creating a conversation from the embedded list switches back to the Chat tab.

Done criteria:

- Chat, Voice, Memory, Goals, and Conversations feel intentionally related.
- No control is clipped by Dynamic Island/status safe areas.

## Phase 8 - Global Sign-Out Placement

Status: first implementation complete.

Goal: sign-out should never compete with primary work actions.

- Move sign-out into a profile/settings/account menu.
- Remove the global floating sign-out button from work screens.
- Keep destructive/session actions visually separated from add/import actions.

Implemented:

- Removed the global floating sign-out button from `HomeShell`.
- Added sign-out to the Accounts app bar account menu.
- Added a confirmation dialog before signing out.
- Added a routing regression test that confirms sign-out is menu-based instead of a floating action.

Done criteria:

- Accounts, Dashboard, and Budgets no longer have sign-out floating over working controls.

## Phase 9 - Visual Design Level-Up

Status: first implementation complete.

Goal: keep the brand warm but make the UI lighter and more shippable.

- Reduce dominant heavy outlines and oversized cards.
- Use smaller metric modules with stronger hierarchy.
- Add consistent spacing tokens for screen padding, section gaps, chips, and rows.
- Tighten type scale for repeated operational screens.
- Use color for semantic states and selected controls, not as a blanket page wash.
- Create a small component checklist for cards, list rows, pills, tab controls, empty states, and snack/progress banners.

Implemented:

- Added stronger global theme defaults for app bars, icon buttons, list tiles, navigation, and popup menus.
- Lightened dashboard surfaces with shared panel, outline, and radius tokens.
- Reduced dashboard card radius, shadow weight, and repeated hard borders on the primary operational sections.
- Removed negative letter spacing from the dashboard components touched in this phase.
- Gave Accounts a useful summary module and denser account rows with account type icons and balance status.
- Tightened the Assistant header weight and tab padding so the top area feels less detached.

Component checklist:

- Cards: 18px radius target, soft outline, minimal shadow, no nested framed sections.
- List rows: icon anchor, title/subtitle/value hierarchy, 16px radius, ink response.
- Pills/tabs: consistent icon weight, 999px selected indicator, readable label padding.
- Empty states: one clear message plus one action, no decorative card stack.
- Snack/progress banners: concise status language, avoid persistent success overlays after completion.
- Metric modules: one primary number per module, supporting values grouped in smaller cells.

Done criteria:

- Screens feel denser, calmer, and more intentional.
- The app looks like a daily-use finance assistant, not a prototype dashboard.

## Phase 10 - Manual Release Test

Goal: test only the stable intended paths.

- Build with:

```bash
flutter run -d 00008150-000C03C83A2B401C --release \
  --dart-define=REX_BACKEND_URL=https://api.goclarity.app
```

- Do not include `REX_NATIVE_IOS_VOICE_ENABLED=true` or `REX_EXPERIMENTAL_NATIVE_IOS_VOICE_ENABLED=true`.
- Test:
  - app restart with existing data
  - dashboard values
  - account detail values
  - CSV import/category completion
  - budgets creation/editing
  - current chat voice call
  - previous conversation voice continuation
  - logout/login restore

Done criteria:

- No false zero dashboard values.
- Voice continues the current chat.
- No duplicate/conflicting floating actions.
- Navigation controls feel aligned and deliberate.
