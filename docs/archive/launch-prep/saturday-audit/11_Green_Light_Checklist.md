# 11 — Final Green-Light Checklist

**Covers:** Go / no-go gates for Saturday. Check boxes only after the owning file’s work is done or explicitly de-scoped in writing.

---

## Must pass (or written de-scope)

| Gate | Pass criteria | Owner file | Status |
| --- | --- | --- | --- |
| Confirm truth | No UI `applied` without backend `applied` | 01 | ☐ |
| Stream honesty | Missing stream `done` shows error | 01 / 05 | ☐ |
| Crash telemetry | Sentry (or equivalent) live on mobile + API | 03 | ☐ |
| Auth locked | `APP_ENVIRONMENT=production`; missing Supabase → 503 not fake user | 04 | ☐ |
| Prompt logging off | `REX_LOG_GROK_PROMPT` hard-disabled / false in prod | 04 | ☐ |
| Auth smoke | Unauth `/chat` → 401; cross-user isolation OK | 04 | ☐ |
| Plaid secrets | Dedicated `PLAID_TOKEN_ENCRYPTION_SECRET` + service role set | 04 / 06 | ☐ |
| Plaid E2E | Link → exchange → sync → transactions visible | 06 | ☐ |
| iOS voice story | Background implemented **or** walk-and-talk removed from iOS marketing + capability flag honest | 07 | ☐ |
| Spanish story | Confirm cards localized + QA **or** Spanish labeled beta | 08 | ☐ |

---

## Should pass for money trust

| Gate | Pass criteria | Owner file | Status |
| --- | --- | --- | --- |
| Confirm retry | Failed confirm shows Tap to retry; pending rehydrates | 05 | ☐ |
| Finance assistant QA | Archived manual checklist green on real account | 06 | ☐ |
| Assistant audit | Finance clarity applies write `source=assistant` audit events | 01 / 06 | ☐ |
| login_required | Update-mode path **or** support playbook for reconnect without dupes | 06 | ☐ |

---

## Should pass for product feel

| Gate | Pass criteria | Owner file | Status |
| --- | --- | --- | --- |
| Goals not in Knows | Knows lists saved memory only; plans live on Goals tab | 02 | ☐ |
| Voice stuck listening | Final transcript always commits or fails honestly; no armed listening with unsent text | 07 | ☐ |

---

## Marketing honesty (required)

| Claim | Allowed only if |
| --- | --- |
| Voice while walking | True on the platform named (Android yes today; iOS only after 07 Phase 1 fix) |
| Full Spanish support | 08 Phases 2–4 complete |
| Cross-platform finance | Web CSV and desktop excluded from claim |
| Enterprise / offline-reliable saves | 05 Phase 1–2 complete |

---

## Already solid (spot-check only)

| Area | Spot-check |
| --- | --- |
| RLS + Plaid secrets table | Client cannot SELECT `plaid_item_secrets` |
| Mobile secrets | Only anon key + backend URL in app config |
| Open Threads | Consent required; max 5 enforced |
| Durable write architecture | Propose → confirm → apply → Knows/Goals refresh |
| Android voice FG | Background session survives app switch |

---

## Go / no-go

- **GO (limited pilot):** All “Must pass” rows checked; marketing honesty table respected; Android-first + iOS-foreground English.
- **NO-GO:** Any Critical truth/auth/logging gate open, or marketing claims platforms/locales that failed their story decision.
