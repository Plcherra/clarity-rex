# 06 — Pre-launch blocking fixes

**Status:** Phases A–E complete on `cursor/phase-b-money-chips`.  
**Depends on:** [`05_simple_brain_implementation.md`](05_simple_brain_implementation.md) (fetch actions exist)  
**Launch binary:** this branch — do **not** ship from `main`

Pre-launch work the owner agreed to fix before launch. Brain cutover lives in plans 01–05. This file is the next numbered plan after 05.

## 1. Goal

Ship a first-run money surface that tells the truth, chat chips that attach finance context, live numbers that survive a ~1h background, Plaid reauth that is actually reconnect, and passwords that are visible and strong.

No onboarding bubble tour. No new insight API. No web search. No new assistant write tools.

## 2. Success criteria for plan 06

| Gate | Pass condition |
|------|----------------|
| First view | After a bank is linked, overview shows leftover **and** one leak sentence from `generateDashboardInsightItems()` |
| Chips | With accounts, empty-chat chips match `hasAssistantFinanceIntent` so send attaches finance context |
| Fetch | Optional one-shot uses existing `buildSummary` / `fetch_spend_insight` / `fetch_account_summary` — no new tools |
| Realtime | JWT refreshed before `.stream()`; stream `onError` restarts watchers; leftover/balances update after ~1h background |
| Plaid | `ITEM_LOGIN_REQUIRED` opens update-mode Link; resync is not reconnect; stale balances do not look current |
| Auth | Show/hide on Sign in **and** Create account; create-account enforces the strength rules below as the user types |
| Sentry | Handled realtime expiry is not a fatal `runZonedGuarded` crash ([PYTHON-B](https://clarity-sd.sentry.io/issues/PYTHON-B), [PYTHON-3](https://clarity-sd.sentry.io/issues/PYTHON-3)) |
| Out of scope | Bubble tour, web search, new write tools, Pocket TTS, ship-from-`main` stay out |

## 3. Phase A — First view: leftover + one leak sentence

The leftover number is already on the dashboard. The leak sentence already exists and is **not mounted**.

**Already painted**

- Leftover / left-to-use: `_FinancialOverviewCard` + `_LeftSplitRow` in `apps/mobile/lib/features/dashboard/presentation/financial_dashboard_overview_card.dart`
- Period leftover: `_PeriodActivityStrip` in `financial_dashboard_activity_period_strip.dart` (`dashboardOverviewLeftThisMonth`)
- Snapshot fields: `DashboardSnapshot.availableThisMonth`, `cashTotal`, `creditAvailableTotal`, `biggestLeaksThisMonth` in `apps/mobile/lib/features/dashboard/domain/dashboard_snapshot.dart`

**Already generated, never called from UI**

- `generateDashboardInsightItems()` in `apps/mobile/lib/features/insights/domain/insight_generator.dart`
- Leak body: `_momLeakInsight` → `l10n.dashboardInsightsMomLeakUp` / `dashboardInsightsMomLeakNew` (`app_en.arb`)
- Tests only: `apps/mobile/test/insight_generator_test.dart`, `apps/mobile/test/financial_integration_contracts_test.dart`
- `InsightsFeedScreen` accepts `liveItems` but nothing in the app routes to it or passes `generateDashboardInsightItems()`

**Do**

- [x] Call `generateDashboardInsightItems(l10n:, snapshot:, budgetPerformance:)` from `_DashboardOverviewBody` (or the overview card). Sources already sit on that widget.
- [x] Mount **one** leak item (`InsightType.momLeak`) next to leftover on the first overview paint after accounts exist. Use `item.body`. Optional: tap → existing `DashboardInsightAnchor.spendingPressure` via `dashboardDeepLinkRequestProvider`.
- [x] If `_momLeakInsight` returns null (no leak / pct ≤ 0), omit the sentence. Do not invent copy.
- [x] Keep leftover as the existing left split / left-this-month figure. Do not rebuild leftover math.

**Do not**

- New insight API, new generator, or `/insights` sync for this sentence
- Mount the full Insights feed or a coach-mark / bubble tour
- Re-add `InsightType.netCashFlow` (generator already skips it; overview already shows cash flow)

**Manual tests**

- [ ] Link a bank → land on overview: leftover visible, plus one leak sentence when `biggestLeaksThisMonth` has a rising category
- [ ] Quiet month (no leak) → leftover only; no fake “watch this” line
- [ ] Sentence copy matches `dashboardInsightsMomLeakUp` / `MomLeakNew` — not new marketing text

## 4. Phase B — Money chips after a bank is linked

Empty chat chips today never match the finance-intent regex, so `fetch_spend_insight` / `fetch_account_summary` never get financial context from a chip tap.

**Today**

- Chips: `_EmptyChatState.prompts` in `apps/mobile/lib/rex/chat/presentation/widgets/chat_transcript.dart`
- Copy: `chatTranscriptPromptRemember` / `ThinkTonight` / `CheckKnows` in `apps/mobile/lib/l10n/app_en.arb` (memory/Knows, not money)
- Attach gate: `shouldAttachAssistantFinancialContext` / `hasAssistantFinanceIntent` in `apps/mobile/lib/features/finance/application/assistant_financial_context_intent.dart`
- Send path: `ChatControllerContext._financialContext` → `ChatControllerSend` in `apps/mobile/lib/rex/chat/application/chat_controller_context.dart` and `chat_controller_send.dart`
- Body fetch: `FINANCE_FETCH_ACTIONS` in `services/rex-api/app/services/capabilities/finance_action_payload.py`; pack builder `finance_capability_fetch.py`

**Do**

- [x] When the user has linked accounts, replace empty-chat chips with **money** prompts that match `assistantDirectFinanceIntentPatterns` or `assistantContextualMoneyIntentPatterns`. Examples that already pass `apps/mobile/test/assistant_financial_context_service_test.dart`:
  - `How much did I spend this week?`
  - `What is my bank balance?`
  - `What accounts do I have?`
- [x] Keep the current memory/Knows chips when there are **no** accounts.
- [x] Pass a `hasLinkedAccounts` (or equivalent) into `ChatTranscript` / `_EmptyChatState`. Read accounts from the existing financial read model / account overview — no new API.
- [x] Chip tap prefills via `onPromptSelected` (same as other chips — user taps send). Attach is computed from the sent text, so money chips post `financial_context` without an auto-send special case.
- [x] Add/adjust widget + intent tests: each money chip string returns true from `shouldAttachAssistantFinancialContext`.

**Do not**

- Add web search
- Add new assistant tools or write capabilities
- Bypass the regex with a “always attach on chip” special case
- Always-on finance dump on every base turn (plan 05 §5 / MASTER_PLAN token budget)

**Manual tests**

- [ ] No accounts → old chips; a chip send does **not** attach finance
- [ ] After link → money chips; tapping one attaches context (network payload has `financial_context`) and Rex can answer from `fetch_spend_insight` / `fetch_account_summary`
- [ ] Typed “hey” still does not attach finance

## 5. Phase C — Optional one-shot finance fetch on Chat open

Not launch-blocking if Phase B attach-on-send works.

**Do (optional)**

- [x] When Chat becomes visible **and** the user has accounts, call existing `AssistantFinancialContextService.buildSummary()` once (`apps/mobile/lib/features/finance/application/assistant_financial_context_service.dart`). Hook: `assistantChatVisibleProvider` via `chatFinancePrefetchProvider` (watched from the empty-chat transcript, not a ChatPage grow).
- [x] Cache that pack for the session so the first money-chip send does not wait on a cold read-model build.
- [x] If a turn needs numbers, Grok still names `fetch_spend_insight` / `fetch_account_summary`. The one-shot does not invent a new action.

**Do not**

- New tools
- Silent user-visible Grok turn on open
- Inject the pack into every base prompt “just in case”

**Manual tests**

- [ ] Open Chat with accounts → at most one prefetch; first money chip still attaches
- [ ] Open Chat with no accounts → no prefetch

## 6. Phase D — Refresh Supabase JWT before `.stream()` + handle `onError`

After ~1h in background the access token dies. Realtime subscribe fails. UI keeps last balances. Sentry:

| Issue | Surface | Error |
|-------|---------|--------|
| [PYTHON-B](https://clarity-sd.sentry.io/issues/PYTHON-B) | web `/app/` | `RealtimeSubscribeException` / `RealtimeCloseEvent(code: 1006)` — **fatal** via `runZonedGuarded` |
| [PYTHON-3](https://clarity-sd.sentry.io/issues/PYTHON-3) | iOS | `InvalidJWTToken: Token has expired … seconds ago` from `supabase_stream_builder.dart` |

Timeouts show up on the same subscribe path when the socket never recovers.

**Today**

- Watchers start in `AppStartupService._startSupabaseWatchers` (`apps/mobile/lib/app/app_startup_service.dart`)
- `_listenIfAuthenticated` calls `listen(onData)` only — **no** `onError`, **no** JWT refresh
- `.stream(primaryKey: ['id'])` sites:
  - `AccountService.watchAccounts` — `apps/mobile/lib/features/accounts/data/account_service.dart`
  - `TransactionService.watchTransactions` — `apps/mobile/lib/features/transactions/data/transaction_service.dart`
  - `BudgetService.watchBudgets` — `apps/mobile/lib/features/budgets/data/budget_service.dart`
  - `CategoryService.watchCategories` — `apps/mobile/lib/features/categories/data/category_service.dart`
  - `ProfileService.watchCurrentProfile` — `apps/mobile/lib/features/profile/application/profile_service.dart`
- Refresh exists but is unused here: `AuthService.refreshAuthSession()` (`apps/mobile/lib/features/auth/application/auth_service.dart`)
- Resume only calls `ui.notifyAll()` — no token refresh, no watcher restart (`HomeShell.didChangeAppLifecycleState` in `apps/mobile/lib/features/shell/presentation/home_shell.dart`)
- Voice stream tickets (`voice_stream_ticket_store.py`, 60s TTL) are a **different** ticket. PYTHON-B/3 are Supabase realtime JWT. Still refresh the session before issuing a voice ticket if the JWT is stale.

**Do**

- [x] Before every `.stream()` subscribe (startup + restart), `await authService.refreshAuthSession()` when a session exists.
- [x] Give every watcher `onError`: refresh session, cancel, resubscribe. Do not leave a dead subscription.
- [x] On real background → resume (`paused`/`hidden` → `resumed`), refresh JWT then restart watchers if the socket is dead. Keep the screenshot `inactive→resumed` skip so the dashboard does not flash-load.
- [x] After a handled 1006 / expired JWT, recover quietly. Do not report it as an unhandled fatal (`ClarityCrashReporting` / `runZonedGuarded` in `apps/mobile/lib/core/observability/clarity_crash_reporting.dart`).
- [x] Prefer one helper (startup service or a small realtime supervisor) so accounts/transactions/budgets/categories share the same refresh+retry. Do not copy-paste five slightly different listeners.

**Do not**

- Lengthen the voice ticket TTL as a substitute for JWT refresh
- Treat resync-Plaid as a fix for stale **realtime** numbers

**Manual tests**

- [ ] Background the app past JWT expiry (~1h) → resume → leftover and transactions move again without a full relaunch
- [ ] Kill realtime (airplane mode then back) → `onError` recovers; UI does not freeze on last paint
- [ ] Web: 1006 during subscribe is handled, not a fatal overlay
- [ ] iOS: expired JWT is handled, not a red error screen

## 7. Phase E — Plaid reconnect (`ITEM_LOGIN_REQUIRED` / update-mode Link)

Resync is not reconnect. Reauth today leaves last balances looking current.

**Today**

- UI already **maps** `login_required` → `PlaidAccountConnectionStatus.loginRequired` (`apps/mobile/lib/features/accounts/data/plaid_account_service.dart`) and shows `plaidAccountStatusLoginRequiredMessage`
- The refresh icon on `loginRequired` still calls `onResync` → `PlaidAccountService.syncItem` → `POST /plaid/sync-item/...` (`plaid_accounts_refresh.dart`, `plaid_account_header.dart`)
- Link token create never sends `access_token` / item id — always a **new** Link:
  - `PlaidLinkService.connectBank` / `RexPlaidApi.createLinkToken` — `apps/mobile/lib/features/plaid/application/plaid_link_service.dart`
  - `PlaidLinkTokenPayload` + `PlaidApiClient.create_link_token` — `services/rex-api/app/services/plaid_api_client.py`
  - `POST /plaid/link-token` — `services/rex-api/app/routes/plaid.py`
- Webhooks handle `ITEM_LOGIN_REPAIRED` only. `ITEM_LOGIN_REQUIRED` / `ITEM`+`ERROR` are not in `ITEM_EVENTS_REQUIRING_ITEM` (`plaid_webhook_service.py`, `plaid_sync_service.handle_webhook_event`)
- Sync/balance failures do not persist `login_required` when Plaid returns `ITEM_LOGIN_REQUIRED`

**Do**

- [x] Persist `status=login_required` when Plaid says `ITEM_LOGIN_REQUIRED` (webhook `ITEM` / `ERROR`, and sync/balance/liabilities API errors). Same for `PENDING_EXPIRATION` → `pending_expiration` if Plaid sends it.
- [x] Add update-mode Link: `create_link_token` accepts the existing item and sends Plaid `access_token` (update mode). Do not start a second Item for the same bank.
- [x] Mobile: `loginRequired` (and pending expiration) CTA opens update-mode Link, not `syncItem`. Wire `PlaidLinkService` + accounts UI (`plaid_account_header.dart`, accounts screen).
- [x] After update-mode success, mark the item `active` and then sync. `ITEM_LOGIN_REPAIRED` already flips status to `active` — keep that.
- [x] While `login_required`, do not present last balances as live/current. Stale timestamp or explicit “needs reconnect” — leftover must not look freshly synced.

**Do not**

- Treat `POST /plaid/sync-item` as reconnect
- Exchange a new public token into a duplicate Item when update-mode is the path
- Hide the login-required pill

**Manual tests**

- [ ] Force `ITEM_LOGIN_REQUIRED` (sandbox reset login) → pill + reconnect CTA; balances not labeled as now
- [ ] Update-mode Link succeeds → status `active`, numbers refresh
- [ ] Resync on a healthy item still only syncs
- [ ] Disconnect still disconnects

## 8. Phase F — Auth passwords

One screen, two modes: `AuthScreen` / `_isSignUp` in `apps/mobile/lib/features/auth/presentation/auth_screen.dart`.

**Show/hide**

The shared password field already has `_obscurePassword` and `authShowPassword` / `authHidePassword`. Owner still asked for the toggle on **both** Sign in and Create account.

- [ ] Confirm the suffix eye works in both modes (web + iOS). If a platform swallows `suffixIcon`, fix that — do not add a second password field.
- [ ] There is no other password field in the Flutter auth tree (`email_confirmation_screen.dart` has none). Do not invent a second create-account route.

**Strength — no client validator exists today**

`friendlyAuthError` only maps a *server* weak-password string to `authErrorWeakPassword` (`apps/mobile/lib/features/auth/application/auth_error_messages.dart`). Sign-up currently sends any non-empty password (`_submit`).

**Default rules (use these; there is nothing to match in-repo):**

| Rule | Requirement |
|------|-------------|
| Length | at least **8** characters |
| Lowercase | at least one `a–z` |
| Uppercase | at least one `A–Z` |
| Digit | at least one `0–9` |

Symbol is **not** required. Three character classes + min length is the mix.

**UI as they type (Create account only)**

- [ ] Under the password field, a live checklist of the four rules. Met → checked/positive color; unmet → muted.
- [ ] Disable **Create account** until all four pass. Show why if they tap early.
- [ ] Sign in: no checklist (existing passwords may be weaker). Keep show/hide.
- [ ] Keep mapping server `weak` / `at least` errors to `authErrorWeakPassword`.
- [ ] Put the predicate in a small testable helper next to auth (not inline in `build`). Tests for each rule and the “all four” gate.

**Manual tests**

- [ ] Sign in: eye toggles visibility
- [ ] Create account: eye toggles; checklist updates per keystroke; `password` / `Password1` fail; `Password1` + 8 chars passes (`Password1` is 9 chars and has upper/lower/digit)
- [ ] Create account with `short` stays disabled; server weak-password still shows the friendly string if it slips through

## 9. Optional / not blocking

| Item | Notes |
|------|--------|
| Sign in with Apple | No Apple auth in the app today. Do not block launch. |
| Per-user talk cap | Usage admin exists (`apps/mobile/lib/features/usage_admin/`, `services/rex-api/app/routes/usage.py`). Grok is unlimited per user today. A cap is product/pricing, not this plan. |

## 10. Forbidden during plan 06

- Bubble / coach-mark onboarding tour
- Web search
- New assistant **write** tools or new fetch tool names
- Pocket TTS
- Shipping the launch binary from `main` (launch = `plan/04-aggressive-deletion`)
- New insight HTTP API or a second leak generator
- Always-on finance/Knows on every base Grok turn
- Reintroducing plan-04 kill-list understanding (regex as a **brain**)
- New planning files under `docs/`

## 11. Definition of done

- Phases A, B, D, E, F implemented and manually checked
- Phase C optional; note in the PR/commit if skipped
- No new tools, no tour, no `main` ship
- `plans/` remains the only execution-plan home; this file is 06
