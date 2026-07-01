# Clarity Flutter Web — Master Plan

Ship **one Flutter codebase** (`apps/mobile`) as a **PWA at `app.goclarity.app`** with **full product parity** before public launch:

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
| **P2** | [P2_ADAPTIVE_SHELL.md](./P2_ADAPTIVE_SHELL.md) | P1 | 5–7 days | Not started |
| **P3** | [P3_REX_CHAT_KNOWS.md](./P3_REX_CHAT_KNOWS.md) | P1, P2 | 4–6 days |
| **P4** | [P4_PLAID_WEB.md](./P4_PLAID_WEB.md) | P1, P2 | 5–8 days |
| **P5** | [P5_VOICE_WEB.md](./P5_VOICE_WEB.md) | P1, P3 | 5–8 days |
| **P6** | [P6_PWA_DEPLOY.md](./P6_PWA_DEPLOY.md) | P1–P5 | 3–5 days |
| **P7** | [P7_NATIVE_DESKTOP.md](./P7_NATIVE_DESKTOP.md) | P6 | 1–2 weeks (optional) |

**Do not start the next phase until the current phase exit criteria pass.**

P3 and P4 can run in parallel only if two people work on separate branches; otherwise **sequential P1 → P2 → P3 → P4 → P5 → P6**.

## Architecture

```text
goclarity.app        → Astro marketing (apps/web)
app.goclarity.app    → flutter build web (apps/mobile)
api.goclarity.app    → rex-api
Supabase             → Auth + Postgres
```

## Cross-cutting rules (all phases)

- **One brain, one truth** — no web-only Rex recall patches (`.cursor/rules/REX-BRAIN-RULES-md.mdc`).
- **File size** — split before any file exceeds 400 lines (`.cursor/rules/FILE-SIZE-AND-SPLIT-md.mdc`).
- **Honest capability gates** — disable with clear copy; never fake Plaid/voice/memory success.
- **No second web app** — product stays in `apps/mobile`; `apps/web` is marketing/legal only.

## Known blockers (summary)

| Area | Key file | P1 status |
|------|----------|-----------|
| Phone-first shell | `apps/mobile/lib/features/shell/presentation/home_shell.dart` | Unchanged — P2 |
| Native Plaid only | `apps/mobile/lib/features/plaid/application/plaid_link_service.dart` | Guarded — web uses `UnsupportedPlaidLinkLauncher` |
| Plaid backend ready for web | `services/rex-api/app/services/plaid_api_client.py` | Unchanged — P4 |
| Voice uses dart:io WebSocket | `apps/mobile/lib/rex/voice/data/streaming_voice_api.dart` | Disabled on web via `AppCapabilities` — P5 |
| CORS needs web origin | `services/rex-api/app/config.py` | `.env.example` updated; **VPS deploy pending** |
| Platform capability gates | `apps/mobile/lib/core/platform/app_capabilities.dart` | **Added** |
| Web dev script | `scripts/flutter_web_dev.sh` | **Added** |

## Total timeline

~4–6 weeks focused work to public web parity (P1–P6).
