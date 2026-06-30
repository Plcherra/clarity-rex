# Clarity

**Personal finance and life guidance in one calm app — powered by Rex, your AI assistant that knows your money and remembers what matters.**

<p align="center">
  <img src="assets/readme/hero-dashboard.png" alt="Clarity dashboard showing balances, cash flow, and spending by category" width="320" />
</p>

> **Screenshot tip:** Replace `assets/readme/hero-dashboard.png` with your best dashboard shot (dark or light mode). See [Where to add real screenshots](#where-to-add-real-screenshots) below.

---

## Features

- **Unified financial dashboard** — Balances, monthly cash flow, spending by category, and account health in one place.
- **Plaid bank sync** — Connect checking, savings, and credit accounts; sync transactions automatically.
- **Budgets by category** — Set monthly, weekly, or custom budgets driven by your real transaction history.
- **Transactions & CSV import** — Browse history by month or category; import statements with AI-assisted categorization.
- **Rex chat assistant** — Talk to Rex about money, goals, and life context with the same data you see in the app.
- **Knows (Rex memory)** — Saved, categorized knowledge (People, Events, Places, Goals, Preferences, Facts) you control and edit.
- **Goals & commitments** — Track goals and accountability items alongside Rex conversations.
- **Voice mode** — Hands-free Rex via cloud voice sessions, with usage tracking in Profile.
- **Multilingual UI** — English and Spanish (more locales planned); finance and memory labels stay honest across languages.
- **Dark-first design** — Polished dark theme with optional light mode and system appearance.

---

## Screenshots

| | |
|---|---|
| **Dashboard** — Total balance, income vs spending, cash-flow chart | **Accounts** — Plaid-connected accounts with sync status |
| ![Dashboard](assets/readme/02-dashboard.png) | ![Accounts](assets/readme/03-accounts.png) |
| **Budgets** — Period picker, budget vs spent insights, category amounts | **Transactions** — Monthly history with search and filters |
| ![Budgets](assets/readme/04-budgets.png) | ![Transactions](assets/readme/09-transactions.png) |
| **Chat with Rex** — Quick prompts and message composer | **Knows tab** — Searchable saved memory by entity type |
| ![Rex Chat](assets/readme/05-rex-chat.png) | ![Knows](assets/readme/06-knows.png) |
| **Goals** — Goals and commitments empty state / list | **Voice usage** — Rex voice minutes and call activity |
| ![Goals](assets/readme/07-goals.png) | ![Voice](assets/readme/08-voice.png) |

<details>
<summary>Additional placeholders (onboarding, settings, light mode)</summary>

| Screen | Placeholder |
|--------|-------------|
| Login / onboarding | `assets/readme/01-onboarding.png` |
| Profile & settings (language, appearance, MFA) | `assets/readme/10-profile-settings.png` |
| Dashboard (light mode) | `assets/readme/11-dashboard-light.png` |

</details>

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| **Mobile app** | [Flutter](https://flutter.dev) 3.x, Dart 3.11+ |
| **State management** | [Riverpod](https://riverpod.dev) |
| **Backend API** | Python [FastAPI](https://fastapi.tiangolo.com) (`services/rex-api` in monorepo) |
| **Database & auth** | [Supabase](https://supabase.com) (Postgres, Auth, Edge Functions, RLS) |
| **Bank connections** | [Plaid](https://plaid.com) (via `vendor/plaid_flutter`) |
| **Rex intelligence** | [Grok](https://x.ai) via Rex API — chat, voice, memory, and recall orchestration |
| **Charts** | [fl_chart](https://pub.dev/packages/fl_chart) |
| **Localization** | Flutter gen-l10n (`lib/l10n/`) |

The mobile app never holds server secrets. OpenAI categorization and email run in Supabase Edge Functions; Grok keys live on the Rex API server.

---

## Key Capabilities

### Rex Brain (chat & voice)

Rex is not a separate app — it lives inside Clarity and reads the same financial read models as Dashboard, Budgets, and Transactions.

- **One brain path** for chat and voice: intent check → minimal context → optional backend action → Grok response → light truth check.
- **Honest sourcing** — Saved memory vs chat search vs financial data are labeled separately in prompts.
- **No fake actions** — Rex only claims a save, budget change, or memory write after the backend confirms it.
- **Voice** — Cloud voice sessions (streaming when enabled); usage visible under Profile → Rex and voice.

Architecture details: [`docs/brain/REX_BRAIN_ARCHITECTURE.md`](../../docs/brain/REX_BRAIN_ARCHITECTURE.md)

### Knows (memory)

- Entity-based memory: People, Events, Places, Goals, Preferences, Facts.
- **Knows tab** mirrors what Rex can retrieve as *saved* knowledge — not automatic chat logging.
- Search, filters, and per-item edit/delete; recall from chat can propose saves with explicit confirmation.

### Finance sync

- **Plaid** — Primary source for live accounts and transactions.
- **CSV import** — Fallback path with AI categorization through Supabase Edge Functions.
- **Single read model** — `FinancialReadModelService` feeds Dashboard, Budgets, Transactions, and Rex financial context.
- **Merchant learning** — Category corrections can propagate to matching transactions.

Finance truth rules: [`docs/FINANCE_SOURCE_OF_TRUTH.md`](../../docs/FINANCE_SOURCE_OF_TRUTH.md)

### Budgets

- Monthly, weekly, and custom periods.
- Categories seeded from transaction history (including future months).
- Collapsible insights and full-page scroll for comfortable editing on device.
- Localized category *display* labels; English canonical names stored in the database.

### Goals & accountability

- Goals tab under Assistant with add goal / add commitment flows.
- Wired to Rex API accountability endpoints; Rex can discuss progress using the same records.

---

## Getting Started (Local Development)

### Prerequisites

- Flutter SDK compatible with `sdk: ^3.11.4` (see `pubspec.yaml`)
- Xcode (iOS) and/or Android Studio (Android)
- [Supabase CLI](https://supabase.com/docs/guides/cli) for migrations (optional for app-only work)
- Running **Rex API** locally or a deployed instance (`services/rex-api`)

### 1. Clone and install

From the repository root:

```bash
cd apps/mobile
flutter pub get
```

Generate localizations after editing `.arb` files:

```bash
flutter gen-l10n
```

### 2. Configure environment

Copy the example env file:

```bash
cp .env.example .env
```

Fill in public client values only:

```dotenv
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_ANON_KEY=your-public-anon-key
REX_BACKEND_URL=http://localhost:8000
REX_CLOUD_VOICE_ENABLED=true
REX_STREAMING_VOICE_ENABLED=true
```

Alternatively, pass config at run time (dart-define wins over `.env`):

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-project-ref.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-public-anon-key \
  --dart-define=REX_BACKEND_URL=http://localhost:8000
```

**Never** put `OPENAI_API_KEY`, Grok keys, or Plaid secrets in the Flutter app.

### 3. Start Rex API (backend)

From the monorepo root, run the Rex API (see [`services/rex-api/README.md`](../../services/rex-api/README.md) if present, or [`docs/BACKEND_DEPLOY_RUNBOOK.md`](../../docs/BACKEND_DEPLOY_RUNBOOK.md)):

```bash
# Example — adjust to your local Python/uvicorn setup
cd services/rex-api
# configure .env with Supabase service role, Grok, Plaid, etc.
uvicorn app.main:app --reload --port 8000
```

### 4. Supabase (first-time / schema)

Apply migrations from the repo root:

```bash
supabase db push
```

Auth email and Edge Functions: [`docs/SUPABASE_AUTH_EMAIL_SETUP.md`](../../docs/SUPABASE_AUTH_EMAIL_SETUP.md)

### 5. Run the app

```bash
cd apps/mobile
flutter run
```

**iPhone release helper** (from repo root, uses production API by default):

```bash
./scripts/mobile_release_run.sh
```

### 6. Verify

```bash
flutter analyze
flutter test
```

---

## Project Structure (mobile)

```text
lib/
├── app/              # Bootstrap, composition root, UI controllers
├── core/             # Models, Supabase, formatting, l10n
├── features/         # Finance features (dashboard, accounts, budgets, …)
├── rex/              # Assistant: chat, voice, memory, goals
├── services/         # Shared API clients
└── widgets/          # Reusable UI
```

- Entry: `lib/main.dart` → `lib/app/bootstrap.dart`
- Composition: `lib/app/app_composition.dart`
- Feature-first layout under `lib/features/`; all Rex code under `lib/rex/`.

Monorepo map: [`docs/PROJECT_MAP.md`](../../docs/PROJECT_MAP.md)

---

## Roadmap & Status

Clarity is in **active MVP / pilot** development. Core flows work on device; polish and reliability work continue.

| Area | Status |
|------|--------|
| Dashboard, accounts, transactions | Functional with Plaid + CSV |
| Budgets | Functional; category i18n and UX iterating |
| Rex chat & memory (Knows) | Functional; recall → save → confirm hardened |
| Voice | Cloud path production; usage tracking in app |
| Goals & accountability | UI present; completion tracked in plan docs |
| Localization | English + Spanish UI; expanding category coverage |
| Hybrid chat search | Planned ([`docs/brain/REX_BRAIN_HYBRID_CHAT_SEARCH.md`](../../docs/brain/REX_BRAIN_HYBRID_CHAT_SEARCH.md)) |

**Completion tracking:** [`docs/project-completion/00_COMPLETION_MASTER_PLAN.md`](../../docs/project-completion/00_COMPLETION_MASTER_PLAN.md)

**Brain trust & reliability:** [`docs/brain/REX_BRAIN_TRUST_RELIABILITY_PLAN.md`](../../docs/brain/REX_BRAIN_TRUST_RELIABILITY_PLAN.md)

**Localization:** [`docs/i18n/00_LOCALIZATION_MASTER_PLAN.md`](../../docs/i18n/00_LOCALIZATION_MASTER_PLAN.md)

There is no separate `PILOT-FEATURE-TRACKER` file; use the completion master plan and brain master plan as the source of truth for pilot scope.

---

## Where to add real screenshots

1. Create the folder (if it does not exist):

   ```bash
   mkdir -p apps/mobile/assets/readme
   ```

2. Export **6–8 PNGs** from iOS Simulator or a device (2× or 3× scale looks best in GitHub). Suggested mapping from your current builds:

   | File | Suggested capture |
   |------|-------------------|
   | `hero-dashboard.png` | Dashboard with balance card + cash-flow chart (dark) |
   | `01-onboarding.png` | Auth or first-run screen |
   | `02-dashboard.png` | Full dashboard scroll (spending + trends) |
   | `03-accounts.png` | Connected Plaid accounts list |
   | `04-budgets.png` | Budgets with categories expanded |
   | `05-rex-chat.png` | Assistant → Chat, “Rex is ready” |
   | `06-knows.png` | Assistant → Knows with People/Facts cards |
   | `07-goals.png` | Assistant → Goals |
   | `08-voice.png` | Profile → Voice usage charts |
   | `09-transactions.png` | Transactions month list |
   | `10-profile-settings.png` | Profile with language / appearance sheet |
   | `11-dashboard-light.png` | Optional light-mode dashboard |

3. Drop files into `apps/mobile/assets/readme/` — paths in this README are already wired.

4. Register assets in `pubspec.yaml` if you add a new folder (usually under `flutter: assets:`).

5. Commit images separately from code if the repo prefers smaller diffs; GitHub renders them automatically in the README.

---

## Related Documentation

- CSV import & AI categorization contract: [`docs/csv_import_ai_categorization.md`](../../docs/csv_import_ai_categorization.md)
- Voice production path: [`docs/VOICE_SOURCE_OF_TRUTH.md`](../../docs/VOICE_SOURCE_OF_TRUTH.md)
- Memory & recall policy: [`docs/MEMORY_RECALL_SOURCE_OF_TRUTH.md`](../../docs/MEMORY_RECALL_SOURCE_OF_TRUTH.md)
- Beta smoke runbook: [`docs/CLARITY_BETA_SMOKE_RUNBOOK.md`](../../docs/CLARITY_BETA_SMOKE_RUNBOOK.md)

---

## License

Private / unpublished (`publish_to: 'none'`). All rights reserved unless otherwise noted in the repository root.
