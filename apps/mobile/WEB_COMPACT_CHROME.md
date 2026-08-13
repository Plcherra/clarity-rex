# Web compact chrome — follow-up

Working checklist (not product canon). Goal: **phone-width `/app/` looks and behaves like native compact**, especially Dashboard, Budgets, and Chat. Wide `/app/` (≥800px) stays desktop chrome.

**Status:** `todo` · `doing` · `done` · `verify` · `skip`

Update the Status column as we go. Put test notes in the last column.

---

## How the gap works

Almost every “mobile looks better” change already exists in the same Flutter files. Compact chrome is phone **width**, including Flutter web:

```dart
ClarityNativeLayout.active(context)
  == width < 800
```

Narrow web (`goclarity.app/app/` on a phone or a skinny browser) now shares those tokens with iOS/Android. Wide `/app/` (≥800px) stays desktop chrome. Remaining gaps are extra `kIsWeb` branches (section 5) and visual verify — not a second token gate.

`RexUiTokens.isNativeCompactChrome` delegates to `ClarityNativeLayout.active`. `isCompactChrome` is the same width check (used for some confirm/composer numbers).

### Already shared (do not rebuild)

These are **not** `kIsWeb`-gated. If live web is missing them, check deploy / cache / window width first.

| Surface | What |
| --- | --- |
| Dashboard | Overview / Transactions segmented control (`_DashboardSurfaceSwitch`) |
| Dashboard | Month switcher on Overview only |
| Dashboard | Spend-shape **radar** (`CategorySpendRadarChart`) inside Core charts (narrow) or a 2-col row (wide ≥1100) |
| Dashboard | Cash flow, category bars, 6-month trend, spending pressure, budget vs spent, account health |
| Budgets | Period picker, category list, save, manage categories |
| Chat | Same composer, confirm cards, voice entry, attach |

Radar needs **≥3 spend categories** this month or it shows the empty chart message. On a **wide** browser the radar sits beside spending pressure, not in a collapsible “Core charts” group — easy to miss vs phone.

---

## 0. Gate (do this first)

Gate is width-only. VM token tests passed. Chrome browser tests hung on load in this environment.

| ID | Item | Status | Notes |
| --- | --- | --- | --- |
| 0.1 | Change `ClarityNativeLayout.active` to **width-only**: `!isClarityDesktopLayout(context)` (drop `!kIsWeb`) | done | Keep wide `/app/` on desktop tokens |
| 0.2 | Comment / docs on the class: compact chrome is phone **width**, including Flutter web | done | |
| 0.3 | Update `native_layout_tokens_web_test.dart` — narrow web **should** get gutter 0 / native tokens | verify | File flipped (390 full-bleed + 1280 gutter 24). `flutter test --platform chrome` hung at loading (dartaotruntime idle); did not execute |
| 0.4 | Update comments in `native_layout_tokens_test.dart` (“narrow web keeps desktop gutter”) | done | |
| 0.5 | Confirm `rex_ui_tokens_compact_test.dart` still matches (native compact true on 390px VM tests) | done | VM: 17 passed (tokens + phase_e + finance + rex_ui) |
| 0.6 | Confirm `phase_e_native_layout_test.dart` / `finance_native_layout_test.dart` | done | Included in the 17 VM pass |

After 0.1, walk surfaces below and mark `verify` rather than rewriting padding at every call site.

---

## 1. Dashboard (priority)

What phone has that web chrome currently misses:

- Full-bleed shell (gutter 0 vs 24)
- Tighter page / card padding and smaller card radius
- **Flat chart panels** inside one group card (web wraps each graph in its own padded box)
- Collapsible **Core charts / Trend / Spending analysis** on width &lt; 800 (`alwaysExpanded` is desktop-only)
- Overview card, budget card, account-health card density
- Nav: selected-label-only bottom bar (still `!kIsWeb` — see 5.1)

| ID | Item | Status | Notes |
| --- | --- | --- | --- |
| 1.1 | **Verify live `/app/`**: Overview / Transactions switch is present | done | Live build 18 `main.dart.js` has Overview/Transactions getters. `_DashboardSurfaceSwitch` always in shell; no `kIsWeb`. |
| 1.2 | **Verify radar (“Spend shape”)** on Overview → Core charts (narrow) or 2-col (wide) | verify | Live JS has “Spend shape”. Narrow: Core charts child; wide ≥1100: 2-col beside pressure. Needs ≥3 categories or empty-chart copy. No logged-in radar render this pass. |
| 1.3 | After gate: Overview card padding/radius matches phone | verify | `_FinancialOverviewCard` uses `ClarityNativeLayout.active` (pad 12 / radius 12 at 390). No leftover `kIsWeb`. VM tokens: 390 pad 12, radius medium; 1280 desktop. |
| 1.4 | After gate: Core charts group is collapsible on narrow web, graphs **not** double-boxed | verify | `_DashboardChartPanel` is flat `SizedBox` when `active`. `alwaysExpanded: desktop` so ExpansionTile only when width &lt; 800. |
| 1.5 | After gate: Trend + spending-pressure groups collapsed by default on narrow web | verify | `initiallyExpanded: desktop` + `alwaysExpanded: desktop` on Trend / Spending analysis. Core stays `initiallyExpanded: true`. |
| 1.6 | Budget performance card + budget-vs-spent chart density | verify | `_BudgetPerformanceCard` + `_DashboardBudgetChartPanel` use `_dashboardCardPaddingOf` / `active`. No `kIsWeb`. |
| 1.7 | Account health card density | verify | `_AccountHealthCard` uses `_dashboardCardPaddingOf` / `_dashboardCardRadiusOf`. No `kIsWeb`. |
| 1.8 | Transactions surface: filters, lists, category groups look like phone | verify | Lists/groups use `_dashboardCardPaddingOf`; scroll `desktop = isClarityDesktopLayout`. No `kIsWeb`. |
| 1.9 | Account-scoped dashboard (account detail) same Overview / Transactions + charts | done | Same `FinancialDashboardView`. `account_detail_dashboard_parity_test` passed. |
| 1.10 | Empty / loading / resolving dashboard bodies use compact padding | verify | `_DashboardLoadingBody` / empty / resolving / load message all branch on `ClarityNativeLayout.active`. No `kIsWeb`. |
| 1.11 | Manual: tap category bar → category detail; insight deep-link still scrolls | verify | `_openCategoryDetail` → `CategoryDetailScreen`. Deep-link expands Core/Spending when `!desktop` then `ensureVisible`. Anchor unit tests passed. Tap not exercised (no logged-in session). |

---

## 2. Budgets

Functional budgets are shared. Compact chrome is padding / card radius / list density.

| ID | Item | Status | Notes |
| --- | --- | --- | --- |
| 2.1 | Page gutter matches phone (10 vs 16) | todo | `_BudgetsScaffold` |
| 2.2 | Summary cards use native card padding/radius | todo | `budgets_screen_widgets.dart` |
| 2.3 | Category expansion list density | todo | `budget_category_list.dart` |
| 2.4 | Keyboard-open edit + save still works on web | todo | |
| 2.5 | Manage categories overlay: sheet vs dialog (see 5.2) | todo | |

---

## 3. Chat / companion

Composer, lists, and confirm UX still have extra `kIsWeb` / native-compact branches **after** the gate.

| ID | Item | Status | Notes |
| --- | --- | --- | --- |
| 3.1 | Composer: 46px min height, 10px chrome pad, no filled pill | todo | `chat_input_bar` + `RexUiTokens` |
| 3.2 | Transcript side inset 16 (not 36); list gutter 10 | todo | `bubbleSideInsetOf`, `transcriptPaddingHOf` |
| 3.3 | Hide assistant page title on compact (phone already hides it) | todo | `showsAssistantPageTitle` |
| 3.4 | Hide transcript scrollbar on compact | todo | `showsTranscriptScrollbar` |
| 3.5 | Confirm cards **inline** on compact web (today narrow web still auto-opens a modal) | todo | `autoOpensConfirmDialog` — still `!isNativeCompactChrome` |
| 3.6 | Chats list: title-only rows, 28-char titles, denser search field | todo | `listPreviewMaxLines` = 0 on compact |
| 3.7 | Companion overview / Knows / Goals gutters and section gaps | todo | `assistant_overview_page`, `memory_page`, `accountability_page` |
| 3.8 | Companion settings list row padding | todo | |
| 3.9 | Attach: keep web file picker (no fake camera). Optional: gallery vs files later | skip | Capability, not chrome |
| 3.10 | Voice: keep foreground-only on web | skip | Capability, not chrome |

---

## 4. Rest of compact chrome (after 1–3)

Same gate; verify rather than rewrite.

| ID | Item | Status | Notes |
| --- | --- | --- | --- |
| 4.1 | Accounts list / header / empty state | todo | |
| 4.2 | Profile, language picker, usage summary | todo | |
| 4.3 | Activity (transaction history) page padding | todo | |
| 4.4 | Account selection screen | todo | |
| 4.5 | Snackbars: compact vs wide (`clarity_snackbar` still treats all web as wide) | todo | Separate `kIsWeb` |

---

## 5. Extra `kIsWeb` chrome (not unlocked by 0.1)

Decide per item: follow compact width, or keep web-specific.

| ID | Item | Status | Notes |
| --- | --- | --- | --- |
| 5.1 | Bottom nav: `onlyShowSelected` labels on compact web (today native-only) | todo | `home_shell_layout.dart` |
| 5.2 | Overlays: bottom sheets on compact web vs always-dialog on web | todo | `clarity_adaptive_overlay.dart` |
| 5.3 | Visible web scrollbars vs native thin ones | todo | `clarity_scroll_behavior.dart` |
| 5.4 | Add-account dialog centering wrapper | todo | cosmetic |

**Out of this tracker (product capabilities, not chrome):** CSV import, camera, background voice, native Plaid Link, OS mic-settings deep link, haptics.

---

## 6. Tests to run

| ID | Item | Status | Notes |
| --- | --- | --- | --- |
| 6.1 | `flutter test test/native_layout_tokens_test.dart test/phase_e_native_layout_test.dart test/finance_native_layout_test.dart test/rex_ui_tokens_compact_test.dart` | todo | VM |
| 6.2 | `flutter test --platform chrome test/native_layout_tokens_web_test.dart` | todo | After 0.3 |
| 6.3 | Dashboard widget tests that assume layout (if any fail after gate) | todo | |
| 6.4 | `chat_web_parity_test.dart` / conversation history tile tests | todo | |

---

## 7. Manual pass (narrow Chrome ~390px + wide desktop)

| ID | Item | Status | Notes |
| --- | --- | --- | --- |
| 7.1 | Dashboard Overview: switch, month, radar, collapsible groups | todo | |
| 7.2 | Dashboard Transactions: search / month / categories | todo | |
| 7.3 | Budgets: edit a row, save | todo | |
| 7.4 | Chat: type, confirm card inline, Chats list titles | todo | |
| 7.5 | Knows + Goals density | todo | |
| 7.6 | Wide `/app/` still has 24px gutter and 2-col dashboard | todo | Must not look like a stretched phone |
| 7.7 | Deploy `/app/` and re-check (not just local `flutter_web_dev`) | todo | |

---

## Suggested order

1. **0.1–0.6** gate + unit tests  
2. **1.** Dashboard visual pass (1.1–1.2 verify first on current web)  
3. **3.5** confirm-card modal vs inline (chat feel)  
4. **2** Budgets, **3.1–3.7** Chat lists  
5. **5.1–5.2** nav labels + sheets if still off  
6. **7.** manual + deploy
