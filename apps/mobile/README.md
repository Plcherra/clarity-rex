# Clarity (mobile app)

> Portfolio overview and full screenshot gallery: **[repository README](../../README.md)**

**See your money clearly. Talk to Rex like he actually knows your life.**

<p align="center">
  <img src="assets/readme/hero-dashboard.png" alt="Clarity dashboard — balances, cash flow, and spending by category" width="360" />
</p>

<p align="center">
  <strong>Flutter · Supabase · Plaid · Grok</strong><br />
  <em>Full-stack personal finance app with a built-in AI assistant — chat, voice, memory, and goals in one product.</em>
</p>

---

## The idea

Most finance apps stop at charts. **Clarity combines real bank data with Rex** — an assistant that reads the same numbers you see on screen, remembers what you choose to save, and helps you stay on budget without feeling like a separate chatbot bolted on.

Built as a **production-minded MVP**: dark-first UI, English and Spanish, Plaid sync, CSV import with AI categorization, and trust rules so Rex never fakes a save or invents balances.

---

## App gallery

<p align="center">
  <img src="assets/readme/02-dashboard.png" alt="Dashboard" width="280" />
  &nbsp;&nbsp;
  <img src="assets/readme/05-rex-chat.png" alt="Rex chat" width="280" />
</p>

| | |
|---|---|
| **Dashboard** — Balances, income vs spending, cash-flow chart, category breakdown | **Accounts** — Plaid-connected accounts with sync status |
| ![Dashboard](assets/readme/02-dashboard.png) | ![Accounts](assets/readme/03-accounts.png) |
| **Budgets** — Monthly, weekly, or custom periods; budget vs spent insights | **Transactions** — Searchable history by month and category |
| ![Budgets](assets/readme/04-budgets.png) | ![Transactions](assets/readme/09-transactions.png) |
| **Rex chat** — Ask about money and life context using live app data | **Knows** — Saved memory: People, Events, Places, Goals, Preferences, Facts |
| ![Rex Chat](assets/readme/05-rex-chat.png) | ![Knows](assets/readme/06-knows.png) |
| **Goals** — Track goals and open threads alongside Rex | **Voice** — Hands-free Rex with usage tracking in Profile |
| ![Goals](assets/readme/07-goals.png) | ![Voice](assets/readme/08-voice.png) |

<p align="center">
  <img src="assets/readme/01-onboarding.png" alt="Onboarding" width="220" />
  &nbsp;
  <img src="assets/readme/10-profile-settings.png" alt="Settings" width="220" />
  &nbsp;
  <img src="assets/readme/11-dashboard-light.png" alt="Light mode" width="220" />
</p>
<p align="center"><sub>Onboarding · Profile &amp; settings · Light mode</sub></p>

---

## What Clarity does

### Money, in one place

- **Live bank sync** via Plaid — checking, savings, credit cards
- **Unified dashboard** — balances, monthly cash flow, spending by category
- **Smart budgets** — monthly, weekly, or custom periods seeded from real transaction history
- **Transactions & CSV import** — browse and filter history; import statements with AI-assisted categorization
- **Merchant learning** — category corrections can apply to matching past and future transactions

### Rex — assistant inside the app

- **Chat** — Rex uses the same financial data as Dashboard, Budgets, and Transactions
- **Voice** — cloud voice sessions with usage visible under Profile
- **Knows (memory)** — entity-based saved knowledge you control: People, Events, Places, Goals, Preferences, Facts
- **Goals & Open Threads** — dedicated Goals tab for objectives and opt-in companion follow-ups
- **Trust by design** — Rex distinguishes saved memory from chat history; durable actions only after backend confirmation

### Polish clients notice

- **Dark-first design** with optional light mode and system appearance
- **English + Spanish UI** with localized category labels
- **Comfortable mobile UX** — collapsible insights, full-page scroll on budgets, keyboard-aware editing

---

## Why this build stands out

| Signal | Detail |
|--------|--------|
| **Real integrations** | Plaid bank sync, Supabase auth/data, Grok-powered Rex API — not a mock UI |
| **One product surface** | Finance and Rex share a single read model; no split-brain data |
| **AI you can trust** | Memory saves, budget changes, and recalls are backend-confirmed and honestly labeled |
| **Shipped flows** | Dashboard, accounts, budgets, transactions, chat, memory, goals, and voice on device |
| **Maintainable codebase** | Feature-first Flutter layout, Python FastAPI backend, clear separation of Rex vs finance |

---

## Tech stack

| Layer | Technology |
|-------|------------|
| Mobile | [Flutter](https://flutter.dev) 3.x · [Riverpod](https://riverpod.dev) |
| Backend | Python [FastAPI](https://fastapi.tiangolo.com) |
| Database & auth | [Supabase](https://supabase.com) (Postgres, Auth, Edge Functions, RLS) |
| Bank data | [Plaid](https://plaid.com) |
| Rex AI | [Grok](https://x.ai) via Rex API — chat, voice, memory, recall |
| Charts & i18n | fl_chart · Flutter gen-l10n (EN / ES) |

Server secrets stay on the backend — the mobile app only holds public client config.

---

## Status

Active MVP / pilot. Core user flows run on device; reliability and localization work continue.

| Area | Status |
|------|--------|
| Dashboard, accounts, transactions | ✅ Plaid + CSV |
| Budgets | ✅ Functional; i18n UX |
| Rex chat, Knows, Goals | ✅ Functional |
| Voice | ✅ Cloud path + usage tracking |
| Localization | ✅ EN + ES UI |

---

<details>
<summary><strong>Local development setup</strong></summary>

### Prerequisites

- Flutter SDK compatible with `sdk: ^3.11.4` (see `pubspec.yaml`)
- Xcode (iOS) and/or Android Studio (Android)
- [Supabase CLI](https://supabase.com/docs/guides/cli) (optional for app-only work)
- Running Rex API locally or deployed (`services/rex-api`)

### Install

```bash
cd apps/mobile
flutter pub get
flutter gen-l10n   # after editing .arb files
```

### Configure

```bash
cp .env.example .env
```

```dotenv
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_ANON_KEY=your-public-anon-key
REX_BACKEND_URL=http://localhost:8000
REX_CLOUD_VOICE_ENABLED=true
REX_STREAMING_VOICE_ENABLED=true
```

Or pass at run time (`--dart-define` overrides `.env`):

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-project-ref.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-public-anon-key \
  --dart-define=REX_BACKEND_URL=http://localhost:8000
```

Never put `OPENAI_API_KEY`, Grok keys, or Plaid secrets in the Flutter app.

### Backend & database

```bash
# Rex API (from services/rex-api — see services/rex-api README)
uvicorn app.main:app --reload --port 8000

# Migrations (from repo root)
supabase db push
```

### Run & verify

```bash
cd apps/mobile
flutter run

flutter analyze
flutter test
```

**iPhone release helper** (repo root):

```bash
./scripts/mobile_release_run.sh
```

</details>

<details>
<summary><strong>Flutter web (PWA at goclarity.app/app/)</strong></summary>

Production web uses the same `apps/mobile` codebase as iOS/Android. See [`docs/PROJECT_STRUCTURE.md`](../../docs/PROJECT_STRUCTURE.md).

**Local dev (Chrome):**

```bash
./scripts/flutter_web_dev.sh          # macOS/Linux
./scripts/flutter_web_dev.ps1       # Windows
```

**Release build** (served at `/app/` on the root domain):

```bash
./scripts/flutter_web_release_build.sh
# Output: apps/mobile/build/web  (built with --base-href=/app/)
```

Windows: `.\scripts\flutter_web_release_build.ps1`

**Full site deploy** (landing + PWA → Cloudflare Pages):

```bash
./scripts/goclarity_web_deploy.sh
```

Windows:

```powershell
.\scripts\goclarity_web_deploy.ps1
# First time: npx wrangler login
```

Stage only (after separate builds): `./scripts/flutter_web_stage_into_landing.sh` or `.\scripts\flutter_web_stage_into_landing.ps1`

**Local dev on Windows** — default uses `web-server` (open http://localhost:8081 manually). Chrome auto-launch: `.\scripts\flutter_web_dev.ps1 -Device chrome`

Regenerate PWA icons: `.\scripts\generate_web_pwa_icons.ps1`

</details>

<details>
<summary><strong>Project structure (mobile)</strong></summary>

```text
lib/
├── app/              # Bootstrap, composition root, UI controllers
├── core/             # Models, Supabase, formatting, l10n
├── features/         # Dashboard, accounts, budgets, transactions, …
├── rex/              # Assistant: chat, voice, memory, goals
├── services/         # Shared API clients
└── widgets/          # Reusable UI
```

Entry: `lib/main.dart` → `lib/app/bootstrap.dart` · Composition: `lib/app/app_composition.dart`

Monorepo map: [`docs/PROJECT_STRUCTURE.md`](../../docs/PROJECT_STRUCTURE.md)

</details>

<details>
<summary><strong>Screenshot assets</strong></summary>

Screenshots live in `apps/mobile/assets/readme/` and are wired in the gallery above.

| File | Screen |
|------|--------|
| `hero-dashboard.png` | Dashboard — balance, monthly summary, cash-flow chart |
| `01-onboarding.png` | Sign in |
| `02-dashboard.png` | Dashboard — categories, income vs spending, trends |
| `03-accounts.png` | Accounts — Plaid-connected cards |
| `04-budgets.png` | Budgets — period picker and budget vs spent |
| `05-rex-chat.png` | Assistant → Chat |
| `06-knows.png` | Assistant → Knows (saved memory) |
| `07-goals.png` | Assistant → Goals |
| `08-voice.png` | Profile → Voice usage |
| `09-transactions.png` | Transactions by month |
| `10-profile-settings.png` | Profile → Language |
| `11-dashboard-light.png` | Dashboard (light mode) |

Original device exports (`IMG_*.PNG`) are kept in the same folder for reference. Loading-state captures were not used in the gallery.

</details>

<details>
<summary><strong>Internal documentation</strong></summary>

- [`docs/MASTER_PLAN.md`](../../docs/MASTER_PLAN.md)
- [`docs/CLARITY_RULES.md`](../../docs/CLARITY_RULES.md)
- [`docs/PROJECT_STRUCTURE.md`](../../docs/PROJECT_STRUCTURE.md)

</details>

---

## License

Private / unpublished (`publish_to: 'none'`). All rights reserved unless otherwise noted in the repository root.
