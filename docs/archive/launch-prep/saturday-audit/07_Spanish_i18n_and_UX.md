# 07 — Spanish, i18n, and UX

**Covers:** Spanish launch completeness (especially save/confirm), remaining hardcoded English, first-time user experience, web honesty, and loading/empty-state polish. Do after safety and reliability — or explicitly label Spanish as beta.

**Primary paths:** `clarity_action_cards_strip.dart`, `app_en.arb` / `app_es.arb`, `durable_write_service.py`, `open_thread_turn_service.py`, `onboarding_screen.dart`, `app_capabilities.dart`

---

## Phase 1 — Launch decision: Spanish scope

### Issue: Spanish incomplete on save/confirm path (H4)

- **Severity:** High (blocker if claiming Spanish launch)
- **Why it matters:** Confirm card headlines and several errors are English while locale infrastructure exists — users feel the product is half-translated on the most trust-sensitive flow.
- **Estimated effort:** Medium
- **Brief fix suggestion:** Either finish Phase 2–3 before Saturday, or market Spanish as beta and keep English as primary launch locale.

---

## Phase 2 — Confirm-card and delete-label l10n

### Issue: Confirm card headlines hardcoded English (A45)

- **Severity:** High
- **Why it matters:** `"Save to Clarity Knows"`, `"Track in Goals"`, `"Delete from Goals"`, etc. never go through ARB.
- **Estimated effort:** Small
- **Brief fix suggestion:** Add arb keys for all headlines in `clarity_action_cards_strip.dart`; generate es strings.

### Issue: Delete button labels hardcoded (`Delete` / `Keep it`) (A46)

- **Severity:** High
- **Why it matters:** Same confirm strip; Spanish users see English on destructive actions.
- **Estimated effort:** Small
- **Brief fix suggestion:** Localize button labels via existing l10n pattern.

### Issue: Plan confirm error hardcoded English (A47)

- **Severity:** Medium
- **Why it matters:** `'Could not confirm the plan save.'` in `chat_controller_actions.dart` bypasses l10n.
- **Estimated effort:** Small
- **Brief fix suggestion:** Use localized error key.

---

## Phase 3 — Backend deterministic locale copy

### Issue: Backend short-circuit strings are English-only (A48)

- **Severity:** High
- **Why it matters:** `durable_write_service.py` and `open_thread_turn_service.py` bypass Grok locale rules with fixed English.
- **Estimated effort:** Medium
- **Brief fix suggestion:** Locale-aware templates for offer/consent/failure/success short-circuits keyed by request locale.

### Issue: Voice timer recovery strings English (A26 — also in 04)

- **Severity:** Medium
- **Why it matters:** Recovery UX breaks Spanish immersion.
- **Estimated effort:** Small
- **Brief fix suggestion:** Move to ARB / `voice_call_controller_l10n.dart`.

---

## Phase 4 — Spanish QA pass

### Issue: Full Spanish save → confirm → Knows/Goals not evidenced (A49)

- **Severity:** High (if Spanish claimed)
- **Why it matters:** Infrastructure can be green while the critical path still shows English.
- **Estimated effort:** Small–Medium (manual)
- **Brief fix suggestion:** Device QA in `es`: chat + voice propose memory/goal/thread → confirm card Spanish → item visible; finance confirm if enabled.

---

## Phase 5 — First-time user experience

### Issue: Onboarding is name-only (M3)

- **Severity:** Medium–High
- **Why it matters:** No bank connect, voice intro, or mic priming — empty finance + unused voice after signup.
- **Estimated effort:** Medium
- **Brief fix suggestion:** Optional post-name step: Connect bank / Import CSV (mobile) / Talk to Rex; request mic permission with clear copy.

### Issue: Empty states partially compensate but are not FTUE (A50)

- **Severity:** Low–Medium
- **Why it matters:** `EmptyAccountsState` / dashboard empty setup help, but discovery is passive.
- **Estimated effort:** Small
- **Brief fix suggestion:** Keep empty states; add one guided CTA from onboarding into Connect bank.

---

## Phase 6 — Web and marketing honesty

### Issue: Web is companion, not parity (M6)

- **Severity:** Medium
- **Why it matters:** Claiming full cross-platform finance/voice overstates CSV-less web and no background voice.
- **Estimated effort:** Small
- **Brief fix suggestion:** Marketing + App Store / site copy: web companion; mobile primary; fix stale Plaid web string (file 05).

### Issue: Loading/empty states adequate but gallery excludes loaders (A51)

- **Severity:** Low
- **Why it matters:** Polish not fully validated in README gallery.
- **Estimated effort:** Small
- **Brief fix suggestion:** Spot-check loaders on Accounts, Dashboard, Plaid resync, chat send before launch screenshots.

---

## Phase 7 — Remaining UI English leftovers

### Issue: Goals tile `'Pause'` hardcoded (A27 — also in 04)

- **Severity:** Low
- **Why it matters:** Minor Spanish gap on Goals tab.
- **Estimated effort:** Small
- **Brief fix suggestion:** Localize label.

### Issue: Accountability raw `error.toString()` (A7 — also in 01)

- **Severity:** Medium
- **Why it matters:** Ugly English errors in Spanish locale.
- **Estimated effort:** Small
- **Brief fix suggestion:** Friendly localized mapping.
