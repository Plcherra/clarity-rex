# 07 — Voice and iOS

**Covers:** iOS background voice gap vs product vision, Android FG service baseline, streaming/REST paths, battery/network concerns, and launch messaging decisions. Do after safety/config — then decide fix vs honest de-scope before marketing.

**Primary paths:** `Info.plist`, `BackgroundVoiceService`, `RexVoiceForegroundService.kt`, `voice_call_controller_*.dart`, `streaming_voice_api_*.dart`, `app_capabilities.dart`

---

## Phase 1 — Launch decision: iOS walk-and-talk

### Issue: iOS background voice not implemented (C3)

- **Severity:** Critical (if voice-while-walking is promised)
- **Why it matters:** Product canon says voice must work while walking; iOS has no `UIBackgroundModes`/`audio` and no `rex/voice_background` handler — screen lock will kill the session.
- **Estimated effort:** Large (implement) / Small (de-scope messaging)
- **Brief fix suggestion:** Either (a) implement iOS background audio session + native bridge matching Android FG service, or (b) remove “walk and talk” from iOS launch marketing and set `supportsBackgroundVoice` honestly.

### Issue: `AppCapabilities` claims background voice on iOS (A38)

- **Severity:** High
- **Why it matters:** Capability flag lies to the rest of the app and to QA.
- **Estimated effort:** Small
- **Brief fix suggestion:** Set `supportsBackgroundVoice: false` on iOS until native bridge ships; keep `true` on Android.

---

## Phase 2 — Android baseline protect

### Issue: Android foreground voice is the strongest path — do not regress (A39)

- **Severity:** Medium (protect)
- **Why it matters:** Android is the best Saturday voice target; regressions here remove the only solid walk-and-talk surface.
- **Estimated effort:** Small (QA)
- **Brief fix suggestion:** Smoke: start voice → background app → continue turn → confirm card still works; verify FG service notification.

---

## Phase 3 — Streaming path stability

### Issue: Voice recovery timers vs engineering rule (A24 — also in 04)

- **Severity:** High
- **Why it matters:** 30s thinking timeout can cut slow turns; confirm state may not survive recovery.
- **Estimated effort:** Medium
- **Brief fix suggestion:** For launch, raise/disable thinking timeout; pause recovery during confirm dialogs.

### Issue: Web voice JWT-in-URL (H3 — also in 03)

- **Severity:** High
- **Why it matters:** Security issue on web voice; native is fine.
- **Estimated effort:** Medium
- **Brief fix suggestion:** Ticket endpoint or defer web voice; redact logs (file 04).

### Issue: Continuous mic + WS + TTS battery/network load (A40)

- **Severity:** Medium
- **Why it matters:** No low-power mode; long walks drain battery and burn STT/TTS quota.
- **Estimated effort:** Large
- **Brief fix suggestion:** Post-launch: adaptive pause, clearer usage metering; for Saturday document expected battery impact.

---

## Phase 4 — Voice confirm parity

### Issue: Voice confirm cards via dialog — protect parity with chat (A41)

- **Severity:** Medium (protect)
- **Why it matters:** Voice must use same durable-write confirm path; any fake-apply bug hits voice too.
- **Estimated effort:** Small (QA) after file 01 fix
- **Brief fix suggestion:** Manual: voice propose memory → dialog confirm → Knows refresh; reject → nothing saved.

### Issue: Experimental native iOS voice bridge must stay off (A42)

- **Severity:** Low
- **Why it matters:** Second assistant pipeline would violate single-brain rule.
- **Estimated effort:** Small
- **Brief fix suggestion:** Keep `REX_EXPERIMENTAL_NATIVE_IOS_VOICE_ENABLED=false`; do not enable for release.

---

## Phase 5 — Platform honesty matrix

### Issue: Cross-platform claims vs reality (A43)

- **Severity:** Medium
- **Why it matters:** Marketing “iOS, Android, web” overstates parity.
- **Estimated effort:** Small
- **Brief fix suggestion:** Publish internal matrix: Android best; iOS foreground; web companion (no CSV, no background voice); desktop unsupported.

| Target | Voice | Background voice | Plaid | CSV |
| --- | --- | --- | --- | --- |
| Android | Yes | Yes (FG service) | Yes | Yes |
| iOS | Yes (foreground) | No | Yes | Yes |
| Web PWA | Yes | No | Yes (JS) | No |
| Desktop | No | No | No | No |

---

## Phase 6 — Lifecycle and reconnect

### Issue: Lifecycle resume exists but offline story is thin (A44)

- **Severity:** Medium
- **Why it matters:** Resume after app switch can race with timers and pending confirms.
- **Estimated effort:** Medium
- **Brief fix suggestion:** On resume, rehydrate pending proposals; do not auto-restart listening over an open confirm; show reconnect copy from existing l10n keys.

---

## Phase 7 — Stuck listening / unsent final transcript

### Issue: Voice final transcript not sent; UI stuck in listening (A77)

- **Severity:** High
- **Why it matters:** Manual smoke (Jul 2026): long utterances and turns after a failed memory save left interim text on screen, mic/stop controls active, and no chat send — user had to recover manually. Core voice promise fails if talking does not become a turn.
- **Estimated effort:** Medium
- **Brief fix suggestion:** Trace `voice_call_controller` phase machine: listening → final STT → commit user message → send via same chat path → idle/thinking. Ensure final transcript always commits or surfaces an honest failure; never leave listening armed with unsent text. Add regression coverage for long utterances and for turns immediately after a clarification/error reply. Do not add artificial timeouts to “fix” races — fix state transitions.

### Issue: Stuck listening more likely after clarification / error turns (A78)

- **Severity:** Medium
- **Why it matters:** Same smoke: hang appeared after Rex’s city-clarification loop; recovery path may not reset listening cleanly when the assistant short-circuits.
- **Estimated effort:** Small–Medium
- **Brief fix suggestion:** After any completed assistant response (including short-circuit clarifications), force a clean listening reset or explicit idle; clear interim transcript if send failed. Coordinate with file 05 recovery/timer work so auto-restart does not re-arm over a half-sent turn.
