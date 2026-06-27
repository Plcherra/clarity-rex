# Charts, Usage, and Finance Visualization Plan

## Goal

Give Clarity users clear finance and voice usage visuals, and give the product owner per-user cost intelligence for pricing decisions after ~4 weeks of real usage data.

Related plans:

- [`05_VOICE_AND_USAGE_PLAN.md`](05_VOICE_AND_USAGE_PLAN.md) — voice path and usage event foundation
- [`02_FINANCE_AND_PLAID_PLAN.md`](02_FINANCE_AND_PLAID_PLAN.md) — financial data truth

---

## Owner usage gap (why you only saw your own data)

Profile → **Voice usage** reads Supabase `user_voice_summaries` with RLS (`auth.uid() = user_id`). It never calls Rex `GET /usage/admin/users`.

| Surface | Data path | Who sees it |
| --- | --- | --- |
| Profile → Voice usage | Supabase `user_voice_summaries` | Logged-in user only |
| Rex `/usage/admin/users` | Service role + owner check | **Not wired to mobile before Phase 1** |
| Rex `/usage/admin/access` | Owner check only | Gates Profile admin row |

**Owner setup (ops):**

1. Set `USAGE_OWNER_USER_ID=<your-auth-uuid>` on Rex API **or** insert your UUID into `admin_users` with role `owner`.
2. Configure rate env vars (see Phase 1) so estimated costs are non-zero.
3. Open **Profile → Usage administration** (owner-only row).

---

## Phase 1 — Owner voice usage and cost intelligence

**Goal:** See every user’s voice/chat/API usage, estimated cost, and daily history for a ~1 month feedback window before pricing.

### Backend

- Restore `unit_count` and `estimated_cost_cents` on `user_usage_events`.
- Add `owner_usage_daily` view: per user, per day — voice seconds, chat/voice LLM calls, STT/TTS seconds, estimated cost.
- Store LLM `unit_count` (tokens when available).
- Compute `estimated_cost_cents` on insert using configurable rates:

| Env var | Default | Used for |
| --- | --- | --- |
| `USAGE_GROK_CENTS_PER_1K_TOKENS` | 0 | LLM events |
| `USAGE_DEEPGRAM_CENTS_PER_MINUTE` | 0 | STT events |
| `USAGE_TTS_CENTS_PER_MINUTE` | 0 | TTS events (duration proxy) |

- API routes:
  - `GET /usage/admin/access` — `{ "authorized": true/false }`
  - `GET /usage/admin/users` — monthly rollup per user (+ email when available)
  - `GET /usage/admin/users/{user_id}/daily?start=&end=` — daily series
  - `GET /usage/admin/summary` — platform totals for current month

### Mobile

- Feature folder: `apps/mobile/lib/features/usage_admin/`
- **Profile → Usage administration** (visible when `/usage/admin/access` is true)
- `OwnerUsageHubScreen` — sortable user table with est. cost
- `OwnerUserDetailScreen` — daily line chart + radar (voice, chat LLM, voice LLM, STT, TTS)

All admin data via Rex API only (never Supabase client).

### One-month feedback playbook

| Week | Action |
| --- | --- |
| 1 | Confirm all active users appear; spot-check one heavy voice user |
| 2 | Export or screenshot top 5 by estimated cost |
| 3 | Compare voice-heavy vs chat-heavy users; note outliers |
| 4 | Decide: flat tier, usage cap, or hybrid; pick primary bill metric |

**Decision prompts:**

- Bill on voice minutes, LLM calls, or blended estimated cost?
- What free tier cap (if any)?
- Which rate card matches your actual provider invoices?

### Phase 1 acceptance

- Owner sees all users in app; normal users do not see admin row
- Per-user estimated cost visible (rates may be rough v1)
- Daily history for current month
- Chat vs voice LLM split visible

**Effort:** ~1.5–2 weeks engineering + 4 weeks observation

---

## Phase 2 — Voice usage charts on Profile (self only)

**Goal:** Every user gets visual usage on Profile. Owner uses Phase 1 for all users; Profile charts show **own** usage only.

| Chart | Type | Data |
| --- | --- | --- |
| Voice minutes this month | Daily line/bar | `user_voice_summaries` daily rows |
| Grok calls | Daily bar | Same |
| STT / TTS | Radar or stacked bar | When available from summaries |

- Package: `fl_chart`
- Shared widgets: `apps/mobile/lib/widgets/clarity_usage_charts.dart`

### Phase 2 acceptance

- At least one daily trend chart + existing summary tiles
- Empty state when no usage
- Totals unchanged (today / week / month)

**Effort:** ~3–5 days

---

## Phase 3 — Financial visualizations

**Goal:** Dashboard and Budgets are visually scannable from the same read model Rex uses.

Data: `DashboardSnapshot` (`monthlyGroups`, `topCategories`, `biggestLeaksThisMonth`, budget performance).

### Tier 1

| Chart | Location | Type |
| --- | --- | --- |
| Monthly cash flow | Dashboard | Grouped bar (income vs spend) |
| Spending by category | Dashboard | Horizontal bar |
| Budget vs spent | Budgets | Progress bars per category |
| Biggest leaks | Dashboard | Ranked horizontal bar |

### Tier 2

| Chart | Location | Type |
| --- | --- | --- |
| 6-month spend trend | Dashboard | Line |
| Income vs spend ratio | Dashboard | Percent bar |
| Account balances over time | Dashboard | Stretch — only if history exists |

Charts live under `apps/mobile/lib/features/dashboard/presentation/charts/`.

### Phase 3 acceptance

- Tier 1 charts match existing text card numbers
- Sensible empty states
- Dark theme via Clarity tokens

**Effort:** Tier 1 ~1 week; Tier 2 ~3–5 days

---

## Build order

1. **Phase 1** — owner admin + cost fields (start here for billing feedback)
2. **Phase 2** — Profile self charts (after shared chart widgets exist)
3. **Phase 3 Tier 1** — can parallelize with Phase 2
4. **Phase 3 Tier 2** — after Tier 1

---

## Files (implementation reference)

| Area | Paths |
| --- | --- |
| Migration | `supabase/migrations/20260626000100_usage_billing_fields_and_owner_view.sql` |
| Backend | `usage_cost_estimator.py`, `usage_tracking_service.py`, `routes/usage.py`, `config.py` |
| Owner mobile | `apps/mobile/lib/features/usage_admin/` |
| Profile charts | `usage_summary_screen.dart`, `clarity_usage_charts.dart` |
| Finance charts | `features/dashboard/presentation/charts/` |
| Docs index | `00_COMPLETION_MASTER_PLAN.md`, `PROJECT_ROUTE_MAP.md` |
