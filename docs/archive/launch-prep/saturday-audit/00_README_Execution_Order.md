# Saturday Launch Audit — Execution Order

**What this pack covers:** Every finding from the Jul 2026 Clarity launch-readiness audit (security, data integrity, voice, Plaid, i18n, UX, privacy, refactoring), organized for execution — plus a cross-platform UI upgrade track (shared Flutter + Android + iOS + dedicated web) and a file-import → Knows/Goals/Threads track.

**Canon note:** These files live under `docs/archive/launch-prep/` (non-canon planning). Product rules remain in `docs/MASTER_PLAN.md`, `docs/CLARITY_RULES.md`, and `docs/PROJECT_STRUCTURE.md`.

---

## Overall priority order

Work files **in this sequence**. Within each file, work phases top-to-bottom.

| Order | File | Theme | Why first / later |
| ---: | --- | --- | --- |
| 1 | [`01_Data_Integrity_and_Truth.md`](01_Data_Integrity_and_Truth.md) | Truth rule, confirm cards, duplicates, audit integrity | Safety + data integrity first |
| 1b | [`14_Companion_Proposal_Honesty.md`](14_Companion_Proposal_Honesty.md) | Auto suggestions Off, ask-before-card, Goal/thread titles | Companion trust — right after confirm honesty; before polish claims |
| 2 | [`02_Chat_and_Knows_UI_Upgrade.md`](02_Chat_and_Knows_UI_Upgrade.md) | Cross-platform UI: shared density/canon, Android, iOS, web marketing + `/app/` | Product feel after truth; platform honesty |
| 2b | [`13_Native_Phone_UI_Remodel.md`](13_Native_Phone_UI_Remodel.md) | Native phone full-bleed / density | Phone feel; does not replace 14 |
| 3 | [`03_Observability_and_Crash_Reporting.md`](03_Observability_and_Crash_Reporting.md) | Sentry / crash + critical events | Blind launch is unacceptable |
| 4 | [`04_Production_Security_and_Config.md`](04_Production_Security_and_Config.md) | Auth bypass, secrets, logging, JWT, validation | Misconfig = catastrophic |
| 5 | [`05_Reliability_and_Error_Handling.md`](05_Reliability_and_Error_Handling.md) | Offline confirm, stream failures, retries | User trust under bad networks |
| 6 | [`06_Plaid_and_Finance_Ops.md`](06_Plaid_and_Finance_Ops.md) | Plaid re-auth, prod smoke, finance QA | Money path must work |
| 7 | [`07_Voice_and_iOS.md`](07_Voice_and_iOS.md) | Background voice, timers, stuck listening, battery | Core product promise — after safety |
| 8 | [`08_File_Import_to_Memory_Goals_Threads.md`](08_File_Import_to_Memory_Goals_Threads.md) | Attach → extract → confirm → Knows/Goals/Threads | Post-truth product capability; reuses confirm stack |
| 9 | [`09_Spanish_i18n_and_UX.md`](09_Spanish_i18n_and_UX.md) | Confirm-card l10n, FTUE, web honesty | Polish / locale claims (after new import strings) |
| 10 | [`10_Privacy_Legal_and_Compliance.md`](10_Privacy_Legal_and_Compliance.md) | Subprocessors, consent, encryption docs | Legal before broad marketing |
| 11 | [`11_Post_Launch_Refactoring.md`](11_Post_Launch_Refactoring.md) | God files, silent catches, desktop | Nice-to-haves last |
| 12 | [`12_Green_Light_Checklist.md`](12_Green_Light_Checklist.md) | Go / no-go gates | Use at ship decision |

---

## Saturday ship decision (summary)

| Path | Condition |
| --- | --- |
| **Ship Android-first + iOS-foreground English pilot** | Complete files 01 + 03–04 (critical phases), Plaid smoke from 06, and explicitly de-scope iOS walk-and-talk + Spanish parity |
| **Do not claim** | Spanish parity, enterprise offline reliability, voice-while-walking on iOS, full web/desktop parity, file → Knows import (unless 08 done) |
| **Defer** | Files 09–11 polish and refactor unless Spanish/web are launch marketing claims; file 08 unless marketing “import notes into Knows” |
| **UI polish (02)** | A–E code largely landed (D marketing honesty done; A116 screenshot refresh open). Run Phase F smoke before claiming polish. Not a blocker for truth/security |
| **Phone remodel (13)** | A–E + G smoke tweaks landed; F close-out optional. Does **not** fix Auto suggestions Off / proposal spam |
| **Companion proposals (14)** | Off means Off, ask-before-card, clean Goal/thread titles — do before claiming calm companion behavior |
| **File import (08)** | Not a Saturday must-pass; place after voice so confirm/truth stack is stable; before Spanish so new copy is localized |

---

## Issue ID legend

IDs match the audit canvas (`C*` Critical, `H*` High, `M*` Medium, `L*` Low). Additional items from the full audit use `A*` (additional) so nothing is dropped. File-import items in 08 use `A80+`.

---

## Suggested 48-hour cut

1. **01** Phase 1–2 (fake-apply + apply honesty)
2. **03** Phase 1 (Sentry mobile + API)
3. **04** Phase 1–3 (auth, prompt logging, Plaid/service-role validation)
4. **06** Phase 1 (prod Plaid smoke)
5. **07** Phase 1 (iOS voice: fix or de-scope messaging) + stuck-listening hang if reproducible
6. **09** Phase 1 (Spanish: finish confirm cards or label beta)
7. **02** Phase F smoke (A–E coded; D honesty landed; A116 screenshots still open) before claiming UI polish
8. **08** only if claiming file→Knows; otherwise leave as post-pilot
