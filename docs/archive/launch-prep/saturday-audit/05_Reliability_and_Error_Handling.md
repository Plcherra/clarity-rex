# 05 — Reliability and Error Handling

**Covers:** Offline/network failure during confirm, retry UX, pending-action ambiguity, voice recovery timers vs engineering rules, and honest error surfaces. After truth + security, this is what keeps users from losing trust on flaky networks.

**Primary paths:** `chat_controller_actions.dart`, `chat_controller_send.dart`, `chat_controller.dart`, `clarity_action_cards_strip.dart`, `voice_call_controller_*.dart`, `chat_api.dart`

---

## Phase 1 — Confirm failure UX

### Issue: No offline/retry story for confirm (H5)

- **Severity:** High
- **Why it matters:** Network drop mid-confirm leaves server pending + ambiguous UI; no retry button.
- **Estimated effort:** Medium
- **Brief fix suggestion:** Keep card `failed` with explicit “Tap to retry”; retry re-sends confirmation with same proposal id; never mark applied without backend proof (see file 01).

### Issue: No connectivity awareness package (A23)

- **Severity:** Medium
- **Why it matters:** Voice/chat fail at the network layer with generic errors; users cannot tell offline vs app bug.
- **Estimated effort:** Medium
- **Brief fix suggestion:** Add connectivity check for voice start and confirm; show localized offline message before attempting WS/REST.

---

## Phase 2 — Stream and hydration reliability

### Issue: Stream-end-without-done silent clear (A1 — also in 01)

- **Severity:** High
- **Why it matters:** Loading stops with no error after partial stream — looks like success.
- **Estimated effort:** Small
- **Brief fix suggestion:** Treat missing `done` as failure; keep prior messages; show retry for the turn.

### Issue: Pending proposal hydration swallowed (A8 — also in 01)

- **Severity:** Medium
- **Why it matters:** Reopen conversation can hide still-pending confirms.
- **Estimated effort:** Small
- **Brief fix suggestion:** Always attempt rehydrate; surface failure; show pending card when present.

---

## Phase 3 — Voice recovery timers (policy tension)

### Issue: Artificial recovery timeouts on voice path (A24)

- **Severity:** High (policy + UX)
- **Why it matters:** Project forbids artificial timeouts for race conditions; 30s thinking / 24s no-speech / 30s playback / 8s WS open / 60s SSE idle can cut slow Grok turns or in-flight confirms.
- **Estimated effort:** Medium
- **Brief fix suggestion:** Document which timers are UX recovery vs forbidden race patches; raise or disable thinking timeout for launch; ensure confirm state survives `_recoverFromStuckThinking`.

### Issue: Stuck-thinking recovery can interrupt confirm (A25)

- **Severity:** High
- **Why it matters:** Auto-restart listening after thinking timeout may drop in-flight save confirm UX.
- **Estimated effort:** Small
- **Brief fix suggestion:** Pause recovery while a clarity confirm dialog/card is active; resume only after resolve/fail.

---

## Phase 4 — Localized, honest error surfaces

### Issue: Hardcoded English recovery strings in voice timers (A26)

- **Severity:** Medium
- **Why it matters:** Breaks Spanish path and feels unpolished when recovery fires.
- **Estimated effort:** Small
- **Brief fix suggestion:** Move `'I did not hear anything...'` (and siblings) into ARB / existing voice l10n helpers.

### Issue: Goals UI hardcoded `'Pause'` and raw errors (A27)

- **Severity:** Low–Medium
- **Why it matters:** Inconsistent with l10n and friendly error mapping.
- **Estimated effort:** Small
- **Brief fix suggestion:** Localize `accountability_page_tiles.dart` Pause label; use friendly errors (see file 01 Phase 5).

---

## Phase 5 — Single pending-action slot risk

### Issue: Plan confirm and delete confirm share one pending_action (A28)

- **Severity:** Medium
- **Why it matters:** Concurrent confirm types in one conversation can overwrite or confuse pending state.
- **Estimated effort:** Large
- **Brief fix suggestion:** Post-launch: model multiple pending proposals or queue; for Saturday, avoid overlapping delete+plan confirms in QA scripts.

---

## Phase 6 — Webhook / async reliability (Plaid-adjacent)

### Issue: Plaid webhook processing is async background — drop risk under load (A29)

- **Severity:** Medium
- **Why it matters:** Missed webhooks leave accounts stuck in syncing/degraded without user-visible recovery.
- **Estimated effort:** Medium
- **Brief fix suggestion:** Verify prod worker durability; add metric for webhook receive vs process; manual resync remains available as safety valve.
