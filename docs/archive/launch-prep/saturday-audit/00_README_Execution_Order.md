# Saturday Launch Audit — Execution Order

**What this pack covers:** Every finding from the Jul 2026 Clarity launch-readiness audit (security, data integrity, voice, Plaid, i18n, UX, privacy, refactoring), organized for execution.

**Canon note:** These files live under `docs/archive/launch-prep/` (non-canon planning). Product rules remain in `docs/MASTER_PLAN.md`, `docs/CLARITY_RULES.md`, and `docs/PROJECT_STRUCTURE.md`.

---

## Overall priority order

Work files **in this sequence**. Within each file, work phases top-to-bottom.

| Order | File | Theme | Why first / later |
| ---: | --- | --- | --- |
| 1 | [`01_Data_Integrity_and_Truth.md`](01_Data_Integrity_and_Truth.md) | Truth rule, confirm cards, duplicates, audit integrity | Safety + data integrity first |
| 2 | [`02_Observability_and_Crash_Reporting.md`](02_Observability_and_Crash_Reporting.md) | Sentry / crash + critical events | Blind launch is unacceptable |
| 3 | [`03_Production_Security_and_Config.md`](03_Production_Security_and_Config.md) | Auth bypass, secrets, logging, JWT, validation | Misconfig = catastrophic |
| 4 | [`04_Reliability_and_Error_Handling.md`](04_Reliability_and_Error_Handling.md) | Offline confirm, stream failures, retries | User trust under bad networks |
| 5 | [`05_Plaid_and_Finance_Ops.md`](05_Plaid_and_Finance_Ops.md) | Plaid re-auth, prod smoke, finance QA | Money path must work |
| 6 | [`06_Voice_and_iOS.md`](06_Voice_and_iOS.md) | Background voice, timers, battery | Core product promise — after safety |
| 7 | [`07_Spanish_i18n_and_UX.md`](07_Spanish_i18n_and_UX.md) | Confirm-card l10n, FTUE, web honesty | Polish / locale claims |
| 8 | [`08_Privacy_Legal_and_Compliance.md`](08_Privacy_Legal_and_Compliance.md) | Subprocessors, consent, encryption docs | Legal before broad marketing |
| 9 | [`09_Post_Launch_Refactoring.md`](09_Post_Launch_Refactoring.md) | God files, silent catches, desktop | Nice-to-haves last |
| 10 | [`10_Green_Light_Checklist.md`](10_Green_Light_Checklist.md) | Go / no-go gates | Use at ship decision |

---

## Saturday ship decision (summary)

| Path | Condition |
| --- | --- |
| **Ship Android-first + iOS-foreground English pilot** | Complete files 01–03 (critical phases), Plaid smoke from 05, and explicitly de-scope iOS walk-and-talk + Spanish parity |
| **Do not claim** | Spanish parity, enterprise offline reliability, voice-while-walking on iOS, full web/desktop parity |
| **Defer** | Files 07–09 polish and refactor unless Spanish/web are launch marketing claims |

---

## Issue ID legend

IDs match the audit canvas (`C*` Critical, `H*` High, `M*` Medium, `L*` Low). Additional items from the full audit use `A*` (additional) so nothing is dropped.

---

## Suggested 48-hour cut

1. **01** Phase 1–2 (fake-apply + apply honesty)
2. **02** Phase 1 (Sentry mobile + API)
3. **03** Phase 1–3 (auth, prompt logging, Plaid/service-role validation)
4. **05** Phase 1 (prod Plaid smoke)
5. **06** Phase 1 (iOS voice: fix or de-scope messaging)
6. **07** Phase 1 (Spanish: finish confirm cards or label beta)
