# Clarity Project Route Map

This map documents the current user-facing product surfaces, their entry points,
and the data source behind each one.

## App Entry And Gating

| Surface | Entry point | Controller/service | Data source | Empty/degraded state |
| --- | --- | --- | --- | --- |
| Splash/loading | `ClarityBootstrap` -> `ClaritySplashScreen` -> `ClarityApp` | `AppComposition`, `SupabaseService` | App config and Supabase init | Boot error screen and loading screen |
| Auth | `ClarityApp._homeForCurrentState` | `AuthController`, `AuthService` | Supabase Auth | Auth form errors |
| MFA verification | `ClarityApp._homeForCurrentState` | `AuthController`, `AuthService` | Supabase MFA | Verification error |
| Onboarding | `ClarityApp._homeForCurrentState` | `ProfileController` | Supabase `profiles` | Profile save error |

## Main Shell

| Tab | Surface | Controller/service | Data source | Empty/degraded state |
| --- | --- | --- | --- | --- |
| Dashboard | `DashboardScreen` -> `FinancialDashboardView` | `DashboardUiController`, `FinancialReadModelService` | Supabase finance tables | Connect bank setup, resolving imported transactions, load error; cash flow, category, leak, and trend charts |
| Accounts | `AccountsScreen` | `AccountUiController`, `PlaidAccountService` | Supabase `accounts`/`plaid_accounts`, Rex `/plaid/*` | Empty accounts, Plaid degraded status |
| Budgets | `BudgetsScreen` | `BudgetUiController`, `BudgetWorkflowService` | Supabase `budgets`, `categories`, `transactions` | Empty budgets/categories; budget vs spent chart |
| Assistant | `AssistantScreen` | Riverpod Rex providers | Rex API and Supabase-backed assistant tables | Per-tab assistant empty/error states |
| Profile | `ProfileScreen` | `ProfileController`, `AuthController`, `ThemeModeController` | Supabase profile/auth, local theme preference | Profile load/update errors |

## Pushed And Modal Surfaces

| Surface | Entry point | Controller/service | Data source | Empty/degraded state |
| --- | --- | --- | --- | --- |
| Account detail | Accounts list item | `AccountUiController`, `DashboardUiController`, `TransactionUiController` | Account-scoped Supabase finance read model | Account load error |
| CSV import fallback | Account detail app bar or Accounts add sheet | `AccountUiController`, `TransactionWorkflowService`, `CsvImportService` | CSV file, Supabase transactions/imports, Edge Function categorization | CSV parse/import errors |
| Transaction review | Dashboard app bar | `DashboardUiController`, `TransactionUiController` | Supabase finance read model | No review items, load error |
| Month detail | Dashboard month card | `DashboardUiController`, `TransactionUiController` | Supabase finance read model | Empty month/error states |
| Category management | Budgets and import banner | `BudgetUiController`, `CategoryWorkflowService` | Supabase categories, transactions, merchant rules | Empty/error states |
| MFA settings | Profile account row | `AuthController` | Supabase MFA | MFA enrollment errors |
| Voice usage | Profile voice usage row | `UsageSummaryController`, `UsageSummaryService` | Supabase `user_voice_summaries` | Usage load error; daily charts on screen |
| Usage administration | Profile owner section (owner only) | `OwnerAccessController`, `UsageAdminApi` | Rex `/usage/admin/*` | Hidden for non-owners |
| Owner usage detail | Usage administration user row | `OwnerUsageController`, `UsageAdminApi` | Rex `/usage/admin/users/{id}/daily` | Daily line/bar + radar charts |
| Theme picker | Profile theme row | `ThemeModeController` | Local shared preferences | Current theme remains active |

## Assistant Inner Tabs

| Tab | Surface | Controller/service | Data source | Empty/degraded state |
| --- | --- | --- | --- | --- |
| Chat | `ChatPage` | `ChatController`, `ChatApi`, `ClarityActionsApi` | Rex `/chat`, optional financial context from Supabase read model | Chat empty state, backend errors |
| Knows | `MemoryPage` | `MemoryController`, `MemoryApi` | Rex `/memory`, `/entities`, `/rules`, `/plans`, `/commitments` | No saved information, memory errors |
| Goals | `AccountabilityPage` | `AccountabilityController`, `AccountabilityApi` | Rex `/accountability/overview`, `/plans`, `/commitments` | No goals/signals, accountability errors; create/complete/miss/archive supported |
| Chats | `ConversationListPage` | `ConversationListController`, `ConversationApi` | Rex `/conversations` and `/conversations/search` | No chats/search results, load errors |

## Product Wiring Decisions

- `UploadScreen` was removed. The canonical CSV fallback path is account-scoped:
  Accounts add sheet or account detail -> CSV file -> account selection/preview
  when needed -> import into a selected account.
- `TransactionReviewScreen` is a real product surface and is reachable from the
  Dashboard app bar for global and account dashboard scopes.

## Backend Route Classification Summary

| Category | Routes |
| --- | --- |
| User-facing now | `/chat`, `/conversations`, `/memory`, `/entities`, `/rules`, `/plans`, `/commitments`, `/accountability/overview`, `/clarity/actions`, `/voice/*`, `/usage/admin/access`, `/usage/admin/summary`, `/usage/admin/users`, `/usage/admin/users/{user_id}/daily`, `/plaid/link-token`, `/plaid/exchange-token`, `/plaid/item-status`, `/plaid/sync-item`, `/plaid/disconnect-item` |
| Backend-only by design | `/plaid/webhook`, Plaid OAuth fallback routes, Apple app site association, `/ready`, `/` |
| Future or underused UI | `/memory/corrections`, entity events, plan milestones, accountability drill-down routes, `/usage/me` |
| Legacy/dead path to review | Supabase `call-openai` client/function path for non-Rex chat completion |
