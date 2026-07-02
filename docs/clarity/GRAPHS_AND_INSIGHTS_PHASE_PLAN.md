# Clarity Graphs & Insights — Phase Plan

**Goal:** Close the gap between what Clarity already computes and what users actually see — without building a second analytics product or breaking financial truth.

**Source audit:** Graphs & Insights Audit (Clarity App), March 2026.

**Related docs (already shipped or partial):**

- [`docs/project-completion/09_CHARTS_USAGE_AND_FINANCE_VIZ_PLAN.md`](../project-completion/09_CHARTS_USAGE_AND_FINANCE_VIZ_PLAN.md) — finance + usage charts (Phases 1–3 largely **complete**)
- [`docs/project-completion/02_FINANCE_AND_PLAID_PLAN.md`](../project-completion/02_FINANCE_AND_PLAID_PLAN.md) — single financial read model
- Rex Brain rules — no fake proactive monitoring; insights must be deterministic or clearly labeled

**Core rules:**

- One data truth: `FinancialReadModelService` → `DashboardSnapshot` / `BudgetPerformanceSnapshot`
- Charts and Rex use the same numbers; never add a parallel analytics engine
- Deterministic UI first; LLM insights stay on-demand in Rex chat unless Phase 5 explicitly ships proactive opt-in
- Do not imply background alerts or monitoring unless backend confirms they are active

---

## Current state (baseline)

| Area | Status |
|------|--------|
| Finance charts (Dashboard) | 5 charts live — strong |
| Finance charts (Budgets) | `BudgetVsSpentChart` — collapsible |
| Dashboard insight cards | 3 text cards — rule-based narratives |
| Usage charts (Profile / Owner admin) | Live |
| Dedicated Insights feature | **Not built** |
| Rex financial analysis | On-demand via chat — production |
| Accountability signals | Backend built — **Goals UI does not render them** |
| `burnRunwayDays` | Computed + sent to Rex — **not on Dashboard** |
| `budget_risk` signal type | Enum exists — detector emits from budget performance snapshot |
| Proactive insight routing | Experimental `RexBrain` only — non-production |

---

## Architecture (keep this shape)

```text
Supabase (accounts, transactions, budgets)
  → FinancialReadModelService
  → DashboardSnapshot + BudgetPerformanceSnapshot
      → Dashboard / Account detail charts & cards
      → BudgetVsSpentChart (Budgets tab)
      → AssistantFinancialContextService → Rex API → Grok

AccountabilityService → Rex prompt (+ future Goals UI)
Supabase user_voice_summaries → Profile usage charts
Rex API /usage/admin/* → Owner usage charts
```

No pie charts, no chart-image export, no Syncfusion — stay on `fl_chart` + custom bars.

---

## Phase 1 — Surface hidden metrics (Priority: High)

**Goal:** Show data that already exists. No new backend models.

**Status:** Complete

### Tasks

- [x] **Burn runway on Account Health card**
  - File: `apps/mobile/lib/features/dashboard/presentation/financial_dashboard_cards.dart` (or `_AccountHealthCard`)
  - Data: `DashboardSnapshot.burnRunwayDays` (already in `dashboard_snapshot.dart` / `dashboard_service.dart`)
  - UX: Show only when computable; empty/hidden when null; same copy tone as existing health headline
  - Rex parity: already in `financial_context_service.dart` as `burn_runway_days`

- [x] **Budget chart on Dashboard (collapsible)**
  - Reuse `BudgetVsSpentChart` from `apps/mobile/lib/features/dashboard/presentation/charts/finance_charts.dart`
  - Pattern: match Budgets tab `ExpansionTile` collapse behavior
  - Placement: after budget performance **text** card or replace redundancy intentionally (text summary + optional expand chart)
  - Data: `BudgetPerformanceSnapshot` — same as Budgets tab

- [x] **Accountability signals on Goals tab**
  - Files: `apps/mobile/lib/rex/accountability/presentation/pages/accountability_page.dart`, `accountability_page_sections.dart`, `accountability_page_tiles.dart`
  - Render existing model fields: `signals`, `ruleRisks`, `recentPatterns` from `AccountabilityOverview`
  - Sections: “Needs attention” (signals), rule risks, recent patterns — calm dark-theme cards, not alarmist
  - Empty states when lists are empty

### Acceptance

- User sees burn runway on Dashboard when data allows
- User can expand budget vs spent chart on Dashboard without opening Budgets tab
- Goals tab shows accountability signals when API returns them
- Chart/card numbers still match Rex context for same snapshot

### Manual test

- Dashboard with linked accounts, budgets, and overspend categories
- Goals tab with seeded accountability signals (API or test fixture)
- Rex finance question still returns consistent numbers

---

## Phase 2 — Dashboard insights strip & UX clarity (Priority: High)

**Goal:** A small deterministic “what to watch” area without a full Insights product.

**Status:** Complete

### Tasks

- [x] **Insights strip (2–3 cards on Dashboard)**
  - New widget under overview or above charts — e.g. `dashboard_insights_strip.dart`
  - Deterministic synthesis from existing snapshot only:
    - Biggest MoM leak (from `biggestLeaksThisMonth`)
    - Top budget overspend (from budget performance)
    - Net cash flow headline (from overview)
  - Each card: one sentence + optional “See chart” scroll/link to section anchor
  - **Not** LLM-generated; **not** persisted feed

- [x] **Clarify overlapping charts**
  - `CategorySpendChart` vs `BiggestLeaksChart`: distinct subtitles (“This month total” vs “Month-over-month pressure”)
  - File: `finance_charts.dart` + dashboard shell labels

- [x] **Dashboard scroll ergonomics**
  - Collapsible sections for chart groups (mirror Budgets `ExpansionTile` pattern)
  - Target file: `financial_dashboard_shell.dart`
  - Default: key sections expanded; long tail collapsible

### Acceptance

- Insights strip visible when at least one signal metric is non-empty
- User can distinguish category spend vs MoM leaks without asking Rex
- Dashboard feels shorter on first paint (collapsed optional blocks)

### Manual test

- Month with no leaks → strip degrades gracefully
- Month with overspend + leak → strip shows both with correct amounts

---

## Phase 3 — Tests, detectors, and backend alignment (Priority: Medium)

**Goal:** Harden what Phase 1–2 expose; fix dead enum / missing detector.

**Status:** Complete

### Tasks

- [x] **Chart widget tests**
  - New: `apps/mobile/test/finance_charts_test.dart`, `clarity_usage_charts_test.dart`
  - Cover: empty states, 6-month window trim, max-Y scaling, dark theme tokens not hardcoded wrong

- [x] **`budget_risk` detector**
  - Backend: `services/rex-api/app/services/accountability_budget_risk.py`
  - Input: budget performance from mobile read model (`budget_performance` query on `/accountability/overview`) or Rex financial context `budget` block
  - Emit `AccountabilitySignalType.budget_risk` when category materially over budget
  - Tests: `services/rex-api/tests/test_accountability_service.py`

- [x] **Mobile renders `budget_risk`**
  - Map in `accountability_models.dart` (partially exists)
  - Show in Goals signals section from Phase 1

- [x] **Radar vs daily usage consistency (owner admin)**
  - Document in code comment which granularity each owner chart uses
  - Optional: align time window labels in `OwnerUserDetailScreen` so owners aren’t misled

### Acceptance

- Widget tests pass in CI for chart empty/non-empty cases
- Integration test: overspent budget produces `budget_risk` signal
- Goals UI shows budget risk with same categories as Dashboard budget card

---

## Phase 4 — Secondary surfaces & Rex bridges (Priority: Medium–Low)

**Goal:** Extend visuals to adjacent tabs; connect chat to UI — still no Insights tab.

**Status:** Complete

### Tasks

- [x] **Transactions tab mini-analytics (optional)**
  - Small sparkline or category summary for current month filter
  - File: `apps/mobile/lib/features/transactions/presentation/`
  - Must use same read model slice — no second aggregation

- [x] **Rex → chart deep links (optional)**
  - When Rex cites a metric in chat, optional chip: “View on Dashboard” with route + scroll target
  - Requires stable section keys in dashboard shell

- [x] **Account detail parity check**
  - Confirm embedded `FinancialDashboardView` stays in sync after Phase 1–2 dashboard changes

### Acceptance

- Transactions mini-analytics totals match Dashboard for same month
- Deep link lands on correct dashboard section

---

## Phase 5 — Dedicated Insights product (Priority: Low / deferred)

**Goal:** Only if product explicitly wants a first-class Insights surface — not required for MVP trust.

**Status:** Partial (5a complete) — persisted feed + opt-in groundwork shipped; push, balance history, and production RexBrain routing remain deferred (5b)

### Scope (future)

- [x] Insights feed route (persisted items, read/unread) — Dashboard-linked `InsightsFeedScreen`, not a 6th nav tab
- [x] User opt-in for proactive monitoring (Profile toggle → `profiles.proactive_insights_enabled`)
- [x] Mobile sends `user_enabled_proactive_insights` on chat requests
- [x] Proactive monitoring opt-in guard in `SimpleRexBrain` production path (not experimental `RexBrain` routing)
- [ ] Account balances over time — requires historical balance storage Plaid may not provide directly
- [ ] Push notifications when new insights are generated
- [ ] Unify experimental `needs_proactive_insight` routing in `RexBrain` with truth policy — **deferred**; production uses `SimpleRexBrain` guard only

### Phase 5a (shipped)

- Supabase: `user_insights` table + `profiles.proactive_insights_enabled`
- Shared deterministic generator: `insight_generator.dart` / `insight_generator.py`
- Rex API: `GET /insights`, `POST /insights/sync`, `PATCH /insights/{id}/read`
- Mobile: insights feed, Dashboard “See all”, Profile opt-in toggle

### Phase 5b (deferred)

- Push notifications (FCM/APNs + backend job)
- Account balance snapshots over time
- Wire experimental `RexBrain` proactive routing to production (explicitly not shipped — would create second brain path)

### Hard stops (from product rules)

- No background monitoring claims without confirmed backend activity
- No LLM insight feed without labeling and persistence model
- No second Rex brain for insights

---

## File map (primary touch points)

| Concern | Location |
|---------|----------|
| Finance charts | `apps/mobile/lib/features/dashboard/presentation/charts/finance_charts.dart` |
| Dashboard layout | `apps/mobile/lib/features/dashboard/presentation/financial_dashboard_shell.dart` |
| Insight cards | `apps/mobile/lib/features/dashboard/presentation/financial_dashboard_cards.dart` |
| Read model | `apps/mobile/lib/features/dashboard/domain/dashboard_snapshot.dart` |
| Rex financial context | `apps/mobile/lib/rex/data/financial_context_service.dart` |
| Budget chart (Budgets) | Budgets presentation + `BudgetVsSpentChart` |
| Usage charts | `apps/mobile/lib/widgets/clarity_usage_charts.dart` |
| Goals / accountability UI | `apps/mobile/lib/rex/accountability/presentation/pages/` |
| Accountability backend | `services/rex-api/app/services/accountability_service.py` |
| Rex prompt financial block | `services/rex-api/app/services/prompt_financial_context.py` |

---

## Success criteria (overall)

- Metrics computed once, shown consistently in charts, cards, Goals, and Rex
- Largest “hidden insight” wins delivered: accountability signals, burn runway, budget visual parity
- Dashboard remains calm and dark-themed — not chart overload
- No FlowForce / scheduling / unrelated product code in Clarity repo
- Phases 1–3 can ship incrementally without waiting for a dedicated Insights tab

---

## Progress log

| Phase | Status | Notes |
|-------|--------|-------|
| Phase 1 | Complete | Hidden metrics surfaced in Dashboard + Goals |
| Phase 2 | Complete | Insights strip + collapsible chart groups + chart subtitles |
| Phase 3 | Complete | Chart tests, `budget_risk` detector, Goals UI wiring, owner chart labels |
| Phase 4 | Complete | Transactions mini-analytics, Rex dashboard deep links, account detail parity |
| Phase 5 | Partial (5a) | Persisted insights feed, opt-in, SimpleRexBrain guard; 5b deferred |

Update this table as phases complete.
