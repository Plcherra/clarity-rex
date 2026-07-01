# Clarity Flutter Web — Master Plan

Ship **one Flutter codebase** (`apps/mobile`) as a **PWA on the root domain** with **full product parity** before public launch:

- Supabase auth (incl. MFA)
- Dashboard, accounts, budgets, transactions
- Rex chat, Knows, goals
- Plaid bank connect on web
- Streaming voice (same Rex Brain path as mobile)

**Desktop strategy:** Flutter Web PWA first. Native `macos/` / `windows/` builds are **P7 (optional, post-launch)**.

## Build order — one phase at a time

| Phase | Plan file | Depends on | Estimate | Status |
|-------|-----------|------------|----------|--------|
| **P1** | [P1_SPIKE_AND_BOOT.md](./P1_SPIKE_AND_BOOT.md) | — | 3–5 days | **Code complete** — manual auth/CORS sign-off pending |
| **P2** | [P2_ADAPTIVE_SHELL.md](./P2_ADAPTIVE_SHELL.md) | P1 | 5–7 days | **Complete** |
| **P3** | [P3_REX_CHAT_KNOWS.md](./P3_REX_CHAT_KNOWS.md) | P1, P2 | 4–6 days | **In progress** |
| **P4** | [P4_PLAID_WEB.md](./P4_PLAID_WEB.md) | P1, P2 | 5–8 days |
| **P5** | [P5_VOICE_WEB.md](./P5_VOICE_WEB.md) | P1, P3 | 5–8 days | **Complete** |
| **P6** | [P6_PWA_DEPLOY.md](./P6_PWA_DEPLOY.md) | P1–P5 | 3–5 days | **Code complete** — deploy + browser smoke pending |
| **P7** | [P7_NATIVE_DESKTOP.md](./P7_NATIVE_DESKTOP.md) | P6 | 1–2 weeks (optional) |

**Do not start the next phase until the current phase exit criteria pass.**

P3 and P4 can run in parallel only if two people work on separate branches; otherwise **sequential P1 → P2 → P3 → P4 → P5 → P6**.

## Architecture (updated — root domain)

Users enter from **`goclarity.app`**. Marketing and product share one brand domain; no separate `app.` subdomain required.

```text
goclarity.app/           → Astro landing, legal, contact (apps/web)
goclarity.app/auth/*     → Email confirm / password reset pages (apps/web)
goclarity.app/app/       → Flutter web PWA (apps/mobile, base-href /app/)
app.goclarity.app        → Optional 301 redirect → goclarity.app/app/
api.goclarity.app        → rex-api
Supabase                 → Auth + Postgres
```

**Cloudflare routing (P6):** one zone (`goclarity.app`). Static Astro at `/`, Flutter build at `/app/*`. Workers or Pages path rules if needed.

**Why `flutter run -d chrome` locally?** Same codebase, local dev server (`localhost:8081`) before anything is deployed to `goclarity.app`. Production users never use Chrome dev — they hit the deployed URL.

## Cross-cutting rules (all phases)

- **One brain, one truth** — no web-only Rex recall patches (`.cursor/rules/REX-BRAIN-RULES-md.mdc`).
- **File size** — split before any file exceeds 400 lines (`.cursor/rules/FILE-SIZE-AND-SPLIT-md.mdc`).
- **Honest capability gates** — disable with clear copy; never fake Plaid/voice/memory success.
- **No second web app** — product stays in `apps/mobile`; `apps/web` is marketing/legal only.

## Known blockers (summary)

| Area | Key file | P1 status |
|------|----------|-----------|
| Phone-first shell | `apps/mobile/lib/features/shell/presentation/home_shell.dart` | **P2 complete** — adaptive rail + max-width finance tabs |
| Native Plaid only | `apps/mobile/lib/features/plaid/application/plaid_link_service.dart` | Guarded — web uses `UnsupportedPlaidLinkLauncher` |
| Plaid backend ready for web | `services/rex-api/app/services/plaid_api_client.py` | Unchanged — P4 |
| Voice uses dart:io WebSocket | `apps/mobile/lib/rex/voice/data/streaming_voice_api.dart` | Disabled on web via `AppCapabilities` — P5 |
| CORS needs web origin | `services/rex-api/app/config.py` | Add `https://goclarity.app` + localhost dev ports |
| Passkeys web SDK | `apps/mobile/web/index.html` + `passkeys_bundle.js` | **Added** |
| Platform capability gates | `apps/mobile/lib/core/platform/app_capabilities.dart` | **Added** |
| Web dev script | `scripts/flutter_web_dev.sh` | **Added** |

## Total timeline

~4–6 weeks focused work to public web parity (P1–P6).
