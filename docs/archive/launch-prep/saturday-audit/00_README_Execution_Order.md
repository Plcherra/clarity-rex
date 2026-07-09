# Saturday Launch Audit — Execution Order

**What this pack covers:** Every finding from the Jul 2026 Clarity launch-readiness audit (security, data integrity, voice, Plaid, i18n, UX, privacy, refactoring), organized for execution — plus a dedicated lightweight Chat/Knows UI upgrade track.

**Canon note:** These files live under `docs/archive/launch-prep/` (non-canon planning). Product rules remain in `docs/MASTER_PLAN.md`, `docs/CLARITY_RULES.md`, and `docs/PROJECT_STRUCTURE.md`.

---

## Overall priority order

Work files **in this sequence**. Within each file, work phases top-to-bottom.

| Order | File | Theme | Why first / later |
| ---: | --- | --- | --- |
| 1 | [`01_Data_Integrity_and_Truth.md`](01_Data_Integrity_and_Truth.md) | Truth rule, confirm cards, duplicates, audit integrity | Safety + data integrity first |
| 2 | [`02_Chat_and_Knows_UI_Upgrade.md`](02_Chat_and_Knows_UI_Upgrade.md) | Lightweight chat/Knows polish; Goals out of Knows | Product feel + canon separation after truth |
| 3 | [`03_Observability_and_Crash_Reporting.md`](03_Observability_and_Crash_Reporting.md) | Sentry / crash + critical events | Blind launch is unacceptable |
| 4 | [`04_Production_Security_and_Config.md`](04_Production_Security_and_Config.md) | Auth bypass, secrets, logging, JWT, validation | Misconfig = catastrophic |
| 5 | [`05_Reliability_and_Error_Handling.md`](05_Reliability_and_Error_Handling.md) | Offline confirm, stream failures, retries | User trust under bad networks |
| 6 | [`06_Plaid_and_Finance_Ops.md`](06_Plaid_and_Finance_Ops.md) | Plaid re-auth, prod smoke, finance QA | Money path must work |
| 7 | [`07_Voice_and_iOS.md`](07_Voice_and_iOS.md) | Background voice, timers, stuck listening, battery | Core product promise — after safety |
| 8 | [`08_Spanish_i18n_and_UX.md`](08_Spanish_i18n_and_UX.md) | Confirm-card l10n, FTUE, web honesty | Polish / locale claims |
| 9 | [`09_Privacy_Legal_and_Compliance.md`](09_Privacy_Legal_and_Compliance.md) | Subprocessors, consent, encryption docs | Legal before broad marketing |
| 10 | [`10_Post_Launch_Refactoring.md`](10_Post_Launch_Refactoring.md) | God files, silent catches, desktop | Nice-to-haves last |
| 11 | [`11_Green_Light_Checklist.md`](11_Green_Light_Checklist.md) | Go / no-go gates | Use at ship decision |

---

## Saturday ship decision (summary)

| Path | Condition |
| --- | --- |
| **Ship Android-first + iOS-foreground English pilot** | Complete files 01 + 03–04 (critical phases), Plaid smoke from 06, and explicitly de-scope iOS walk-and-talk + Spanish parity |
| **Do not claim** | Spanish parity, enterprise offline reliability, voice-while-walking on iOS, full web/desktop parity |
| **Defer** | Files 08–10 polish and refactor unless Spanish/web are launch marketing claims |
| **UI polish (02)** | Ship Goals-out-of-Knows + density pass when feasible after 01; not a blocker for truth/security |

---

## Issue ID legend

IDs match the audit canvas (`C*` Critical, `H*` High, `M*` Medium, `L*` Low). Additional items from the full audit use `A*` (additional) so nothing is dropped.

---

## Suggested 48-hour cut

1. **01** Phase 1–2 (fake-apply + apply honesty)
2. **03** Phase 1 (Sentry mobile + API)
3. **04** Phase 1–3 (auth, prompt logging, Plaid/service-role validation)
4. **06** Phase 1 (prod Plaid smoke)
5. **07** Phase 1 (iOS voice: fix or de-scope messaging) + stuck-listening hang if reproducible
6. **08** Phase 1 (Spanish: finish confirm cards or label beta)
7. **02** Phase 1 (Goals out of Knows) when bandwidth allows
