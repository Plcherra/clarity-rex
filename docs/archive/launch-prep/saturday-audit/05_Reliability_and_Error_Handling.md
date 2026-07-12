# 05 — Reliability and Error Handling

**Status:** Launch slice DONE (2026-07-12). Phase 1 H5 + A23 light + Phase 2 verify + Phase 3 A24/A25 + A26 shipped; A27 already localized; A28/A29 noted only.

**Covers:** Offline/network failure during confirm, retry UX, pending-action ambiguity, voice recovery timers vs engineering rules, and honest error surfaces. After truth + security, this is what keeps users from losing trust on flaky networks.

**Primary paths:** `chat_controller_actions.dart`, `chat_controller_send.dart`, `chat_controller.dart`, `clarity_action_cards_strip.dart`, `voice_call_controller_*.dart`, `chat_api.dart`, `device_connectivity.dart`

**Verification (2026-07-12):**
- Flutter: confirm fail/retry + failed-card visibility tests passed (`chat_controller_test`, `voice_clarity_actions_test`); `pauseForSaveConfirmation` voice test passed.
- Phase 2 A1/A8 already DONE in plan 01 — re-verified in tree (no duplicate work).
- A23 light preflight shipped (no `connectivity_plus`): offline gate before voice `startCall` and confirm; reuses `chatErrorNetwork`.
- Remaining: A28 multi-pending rewrite (post-launch); A29 Plaid webhook durability (Plan 06); Phase 7-style manual network-kill mid-confirm on device.

---

## Phase 1 — Confirm failure UX — DONE (H5); A23 light DONE

### Issue: No offline/retry story for confirm (H5) — DONE

- **Severity:** High
- **Why it matters:** Network drop mid-confirm leaves server pending + ambiguous UI; no retry button.
- **Estimated effort:** Medium
- **Brief fix suggestion:** Keep card `failed` with explicit “Tap to retry”; retry re-sends confirmation with same proposal id; never mark applied without backend proof (see file 01).
- **Done in (2026-07-12):**
  - `pendingClarityActions` now includes `pending` / `applying` / `failed` (`isConfirmActive`) so failed cards stay visible.
  - Confirm/Retry button uses `commonRetry` when `canRetry`; person + generic cards show error + retry.
  - `_confirmPlanSave` always sends `_writeConfirmationPayload` (same `proposal_id`); network/API errors stay on the card; never marks `applied` without backend evidence.
  - Voice dialog re-shows on fail-outside-chat; pause stays active while confirm is failed/applying.
  - Tests: network fail → failed visible → retry same `proposal_id` → applied; widget Retry visibility.

### Issue: No connectivity awareness package (A23) — LIGHT DONE (no connectivity_plus)

- **Severity:** Medium
- **Why it matters:** Voice/chat fail at the network layer with generic errors; users cannot tell offline vs app bug.
- **Estimated effort:** Medium
- **Brief fix suggestion:** Add connectivity check for voice start and confirm; show localized offline message before attempting WS/REST.
- **Done in (2026-07-12) — light launch slice:**
  - No new package (`connectivity_plus` not added).
  - `apps/mobile/lib/core/network/device_connectivity.dart` (+ io/web/stub): deliberate UX preflight `isDeviceLikelyOnline()`.
    - IO: short DNS lookup (API host when remote, else `example.com`), 2s cap — intentional preflight, not a race patch.
    - Web: `navigator.onLine`.
  - Voice: `startCall` aborts with `chatErrorNetwork` when clearly offline (before mic / listen).
  - Confirm: `_confirmPlanSave` and finance `executeClarityAction` abort with `chatErrorNetwork` on the card; never claim save.
  - Post-attempt network failures still map via `friendlyChatApiError` / `friendlyVoiceApiError` as before.
  - Deeper continuous connectivity monitoring remains optional post-launch if needed.

---

## Phase 2 — Stream and hydration reliability — DONE (verified; owned by plan 01)

### Issue: Stream-end-without-done silent clear (A1 — also in 01) — DONE

- **Severity:** High
- **Why it matters:** Loading stops with no error after partial stream — looks like success.
- **Estimated effort:** Small
- **Brief fix suggestion:** Treat missing `done` as failure; keep prior messages; show retry for the turn.
- **Done in:** `chat_controller_send.dart` (plan 01) — stream closed without `ChatStreamDone` sets user-visible error, keeps prior messages, returns null. Re-verified 2026-07-12.

### Issue: Pending proposal hydration swallowed (A8 — also in 01) — DONE

- **Severity:** Medium
- **Why it matters:** Reopen conversation can hide still-pending confirms.
- **Estimated effort:** Small
- **Brief fix suggestion:** Always attempt rehydrate; surface failure; show pending card when present.
- **Done in:** `chat_controller.dart` `_hydratePendingWriteProposal` — always attempts; surfaces `chatPendingWriteHydrationFailed`; attaches pending card when present. Re-verified 2026-07-12. H5 now also keeps **failed** cards visible via `pendingClarityActions`.

---

## Phase 3 — Voice recovery timers (policy tension) — DONE (launch slice)

### Issue: Artificial recovery timeouts on voice path (A24) — DOCUMENTED + ADJUSTED

- **Severity:** High (policy + UX)
- **Why it matters:** Project forbids artificial timeouts for race conditions; 30s thinking / 24s no-speech / 30s playback / 8s WS open / 60s SSE idle can cut slow Grok turns or in-flight confirms.
- **Estimated effort:** Medium
- **Brief fix suggestion:** Document which timers are UX recovery vs forbidden race patches; raise or disable thinking timeout for launch; ensure confirm state survives `_recoverFromStuckThinking`.
- **Done in (2026-07-12):**
  - **UX recovery timers (allowed):** thinking stuck recovery, no-speech empty-turn recovery, stream disconnect recovery, SSE/stream idle as transport health — not used to “win” races against confirm/apply.
  - **Forbidden pattern (not added):** timers that force-mark confirm success or invent apply results.
  - Thinking timeout raised **30s → 90s** (`voiceCallThinkingTimeoutProvider`) for slow Grok.
  - Confirm-active path cancels/gates thinking recovery (see A25).

### Issue: Stuck-thinking recovery can interrupt confirm (A25) — DONE

- **Severity:** High
- **Why it matters:** Auto-restart listening after thinking timeout may drop in-flight save confirm UX.
- **Estimated effort:** Small
- **Brief fix suggestion:** Pause recovery while a clarity confirm dialog/card is active; resume only after resolve/fail.
- **Done in (2026-07-12):**
  - `_recoverFromStuckThinking` no-ops while `_pausedForSaveConfirmation` / `_blockListenForSaveConfirmation` / `_hasPendingSaveConfirmation()` (includes applying + failed).
  - `_hasPendingSaveConfirmation` uses `isConfirmActive`.
  - Voice listener pause/resume uses `isConfirmActive` so mid-`applying` does not resume listening.
  - Resume only after confirm leaves active set (applied / dismissed); failed keeps pause for Retry.

---

## Phase 4 — Localized, honest error surfaces — DONE (launch slice)

### Issue: Hardcoded English recovery strings in voice timers (A26) — DONE

- **Severity:** Medium
- **Why it matters:** Breaks Spanish path and feels unpolished when recovery fires.
- **Estimated effort:** Small
- **Brief fix suggestion:** Move `'I did not hear anything...'` (and siblings) into ARB / existing voice l10n helpers.
- **Done in (2026-07-12):**
  - No-speech timer uses `voiceL10n.voiceFailureDidNotCatch`.
  - Empty-turn / stream disconnect recovery paths already use `voiceL10n` (`voiceFailureDidNotCatch`, `voiceErrorAssistantStreamDisconnected`, `voiceErrorStillDidNotHear`).
  - Remaining diagnostic English in low-level STT service stays off user-facing recovery surfaces.

### Issue: Goals UI hardcoded `'Pause'` and raw errors (A27) — ALREADY DONE / N/A for Pause

- **Severity:** Low–Medium
- **Why it matters:** Inconsistent with l10n and friendly error mapping.
- **Estimated effort:** Small
- **Brief fix suggestion:** Localize `accountability_page_tiles.dart` Pause label; use friendly errors (see file 01 Phase 5).
- **Saturday note:** Pause already uses `l10n.commonPause`. No further change in this slice.

---

## Phase 5 — Single pending-action slot risk — NOTED (no large rewrite)

### Issue: Plan confirm and delete confirm share one pending_action (A28) — NOTED FOR QA

- **Severity:** Medium
- **Why it matters:** Concurrent confirm types in one conversation can overwrite or confuse pending state.
- **Estimated effort:** Large
- **Brief fix suggestion:** Post-launch: model multiple pending proposals or queue; for Saturday, avoid overlapping delete+plan confirms in QA scripts.
- **Saturday QA guidance:** Do not propose/confirm a delete while a plan/memory confirm card is still pending or failed-retryable in the same conversation. One active confirm at a time. Multi-pending rewrite is post-launch.

---

## Phase 6 — Webhook / async reliability (Plaid-adjacent) — NOTED (light)

### Issue: Plaid webhook processing is async background — drop risk under load (A29) — NOTED

- **Severity:** Medium
- **Why it matters:** Missed webhooks leave accounts stuck in syncing/degraded without user-visible recovery.
- **Estimated effort:** Medium
- **Brief fix suggestion:** Verify prod worker durability; add metric for webhook receive vs process; manual resync remains available as safety valve.
- **Saturday note:** Deep worker/metric work belongs with Plan 06. Manual account resync remains the user-facing safety valve for launch. No code change in this slice.
