# 02 — Cross-Platform UI Upgrade (Chat, Knows, Native Polish, Web)

**Covers:** Make Clarity feel lighter and more practical across **Android**, **iOS**, and **web** — without a full redesign or a second design system.

**Canon:** `CLARITY_RULES.md` — Saved Memory in Knows; Goals in Goals; keep them separate. Marketing and UI must not overclaim platform parity (see file 07 matrix / file 09 honesty).

---

## Progress snapshot (Jul 2026)

| Phase | Scope | Status |
| --- | --- | --- |
| **A** | Shared Flutter canon + density | **DONE** (A1–A5) |
| **B** | Android polish | **DONE** code (B1–B3); **B4** screenshots open |
| **C** | iOS polish | **DONE** code (C1–C3); **C4** screenshots open |
| **D** | Web marketing (`apps/web`) | **DEFERRED** — skipped this pass; do after F smoke if claiming landing |
| **E** | Flutter web `/app/` | **DONE** code (E1/E3/E4); **E2** needs browser smoke in F |
| **F** | Cross-platform verify | **OPEN** — use smoke list below |

**Claim rule:** Do not market “redesigned on every platform” until Phase F is checked for the platforms named in the claim.

**Out of this file:** background voice (07), Plaid prod smoke (06), Spanish FTUE (09), file→Knows (08), legal substance (10), desktop (11), full rebrand.

---

## Primary paths

| Surface | Paths |
| --- | --- |
| Shared Flutter | `chat_message_bubble.dart`, `chat_transcript.dart`, confirm cards, `saved_memory_tile_shell.dart`, `RexUiTokens`, `clarity_sheet_insets.dart`, Knows/Goals sheets |
| Android / iOS | Safe areas, system bars, sheets, foreground voice chrome |
| Web marketing | `apps/web` Astro — **deferred (Phase D)** |
| Web app | Flutter `/app/` — `AppCapabilities`, 920px column, honest voice/attach copy, `flutter_bootstrap.js` |

---

# Phase A — Shared Flutter: canon + density — DONE

### A1 Goals out of Knows (A70) — DONE
Knows list/filters force empty plans/goals; empty copy is facts/people/preferences only.

### A2 Chat bubbles lighter (A71–A72) — DONE
User bubbles use `accentSoft` + `textPrimary`. Shared `bubblePaddingH/V`, `messageGap`, `bodyMedium` / height 1.35.

### A3 Knows lean rows (A73–A74) — DONE
Row = title + optional one-line detail + type. Importance/dates in edit sheet. Shared `memoryTilePadding*` / `memoryTileRadius`.

### A4 Confirm strip slim (A75) — DONE
Shared `confirmCardPadding` / `confirmCardGap` / `confirmButtonHeight`; no drop shadow; truth-honest confirm/dismiss.

### A5 Shell density (A100) — DONE
Goals reuse Knows tile tokens; composer `composerPadding*` + `bodyMedium`. Finance redesign untouched.

---

# Phase B — Android — code DONE; screenshots open

### B1 System UI (A101–A102) — DONE
Sheets `useSafeArea` + `claritySheetPadding`. Confirm dialog `SafeArea`. `ClarityTheme.systemUiOverlayStyle` + `AnnotatedRegion`.

### B2 Material sheets (A103) — DONE
Knows/Goals/attach/settings sheets use shared sheet helper; attach uses theme drag handle.

### B3 Voice chrome (A104) — DONE
Voice panel H padding = composer; `bubbleSideInset` 36. FG service untouched (file 07).

### B4 Play screenshots (A105) — OPEN (manual)
Refresh chat / Knows / Goals / voice captures after device QA. Sync to Phase D if landing reuses them.

---

# Phase C — iOS — code DONE; screenshots open

### C1 Safe areas / nav density (A106–A107) — DONE
Chat body `SafeArea(bottom: false)`; composer owns bottom. `clarityScrollBottomClearance` on Knows/Goals/Chats. Assistant header denser; `toolbarHeight` 48.

### C2 Sheets + haptics (A108) — DONE
`showClarityModalBottomSheet` (drag, dismiss, safe area, grabber). Confirm/dismiss use existing light haptics.

### C3 Foreground voice (A109) — DONE
Compact wave; smaller controls; lighter status. Background walk-and-talk still file 07.

### C4 App Store screenshots (A110) — OPEN (manual)
Same as B4 for iOS captures; sync with Phase D when marketing runs.

---

# Phase D — Web marketing (`apps/web`) — DEFERRED

Skipped this pass (user chose E over D). Still open when claiming the landing:

| ID | Issue | Notes |
| --- | --- | --- |
| A111 | Hero clutter / weak brand | One composition first viewport |
| A112 | Product gallery honesty | No Goals-in-Knows; no false “full web parity” |
| A113 | Legal page readability | Presentation only — file 10 owns substance |
| A114 | Mobile responsive / perf | 375–430px QA; don’t break `/app/` deploy |
| A115 | Download / login CTAs | Honest Open web app vs store links |
| A116 | Screenshot sync | After A–C (+ E) look right |

---

# Phase E — Flutter web `/app/` — code DONE; browser smoke in F

### E1 Capability honesty (A117) — DONE
Web attach tooltip = files only. CSV disabled + mobile-only copy. Plaid unavailable string no longer “coming soon on web” (web Plaid stays on). Voice honesty → E3.

### E1 Layout column (A118) — DONE
Assistant header + tabs constrained to 920px. Add-account dialog centered/max-width on web.

### E2 Density / keyboard (A119–A120) — OPEN (smoke only)
Shared Phase A/B/C patterns apply on web. No web-only widget fork. Verify in Phase F browser smoke.

### E3 Voice honesty (A121) — DONE
Tooltips + inline panel: browser session / keep tab open. Unavailable path points to chat/mobile. Background voice off via `AppCapabilities`. JWT-in-URL remains file 04/07.

### E4 Boot failure UI (A122) — DONE (UI)
Friendlier copy in `apps/mobile/web/flutter_bootstrap.js`. Deploy ops still in `apps/web` README / scripts.

---

# Phase F — Smoke test list (do this next)

Check each box on the platforms you claim. Mark **N/A** if that surface is out of launch scope.

## F0 — Automated (quick)

```bash
cd apps/mobile
flutter test test/chat_message_bubble_test.dart test/chat_input_bar_test.dart test/memory_page_test.dart test/voice_clarity_actions_test.dart
```

- [ ] All four suites pass

## F1 — Canon + density (every Flutter surface you ship)

| # | Check | Android | iOS | `/app/` |
| --- | --- | :---: | :---: | :---: |
| 1 | Knows has **no** Goals / plans group or plan tiles | ☐ | ☐ | ☐ |
| 2 | Knows empty copy does **not** mention goals | ☐ | ☐ | ☐ |
| 3 | Goals tab still shows plans + Open Threads | ☐ | ☐ | ☐ |
| 4 | Chat: soft user bubbles; readable light **and** dark | ☐ | ☐ | ☐ |
| 5 | Chat: bubbles not overly padded; transcript feels dense but readable | ☐ | ☐ | ☐ |
| 6 | Knows rows: title + optional one line + type; no importance/date chrome in list | ☐ | ☐ | ☐ |
| 7 | Knows edit sheet still shows importance + dates | ☐ | ☐ | ☐ |
| 8 | Confirm card: slim, no heavy shadow; Confirm/Dismiss obvious | ☐ | ☐ | ☐ |
| 9 | Confirm → item appears in Knows or Goals; Rex does not claim saved before confirm | ☐ | ☐ | ☐ |
| 10 | Goals tiles match Knows density (not card-heavy) | ☐ | ☐ | ☐ |

## F2 — Android-only

| # | Check | Pass |
| --- | --- | :---: |
| 11 | Gesture nav / 3-button: chat composer, Knows list, sheets clear of system bars | ☐ |
| 12 | Status bar icons readable in light and dark | ☐ |
| 13 | Knows create/edit, attach, Goals detail sheets: drag handle + dismiss OK | ☐ |
| 14 | Voice panel aligns with composer; confirm during voice usable | ☐ |
| 15 | FG / notification voice behavior **unchanged** (no regression from UI polish) | ☐ |

## F3 — iOS-only

| # | Check | Pass |
| --- | --- | :---: |
| 16 | Notch / Dynamic Island / home indicator: chat send, attach sheet, Knows edit, voice panel not clipped | ☐ |
| 17 | Assistant tabs + header feel denser; back swipe still works | ☐ |
| 18 | Sheets: drag-to-dismiss + grabber; confirm/dismiss light haptic | ☐ |
| 19 | Foreground voice chrome matches chat density | ☐ |
| 20 | Do **not** expect background walk-and-talk (file 07) | ☐ noted |

## F4 — Flutter web `/app/`

| # | Check | Pass |
| --- | --- | :---: |
| 21 | Wide desktop: assistant header + content stay in ~920px centered column (not full-bleed stretch) | ☐ |
| 22 | Mic tooltip / active voice hint: browser / keep tab open (not “full mobile voice”) | ☐ |
| 23 | Attach tooltip: file-oriented (not “file or image” if that overclaims) | ☐ |
| 24 | Add account: CSV disabled with mobile-only copy; Plaid available if web Link works | ☐ |
| 25 | Chat send + streaming reply scroll OK (desktop Chrome) | ☐ |
| 26 | Mobile Safari (or narrow Chrome): composer not permanently covered; can send | ☐ |
| 27 | Confirm strip usable with mouse/touch; truth-honest after confirm | ☐ |
| 28 | Knows / Goals density readable on wide + narrow | ☐ |
| 29 | Boot: normal load shows “Loading Clarity…” then app (not stuck blank) | ☐ |
| 30 | Optional: break asset path once in staging → friendly boot error (refresh / wrong files), not silent blank | ☐ |

## F5 — Marketing / store (only if claiming those surfaces)

| # | Check | Pass |
| --- | --- | :---: |
| 31 | Phase D still deferred — landing not claimed updated | ☐ / N/A |
| 32 | Play screenshots match shipping density + Knows-without-Goals (B4) | ☐ / N/A |
| 33 | App Store screenshots same (C4) | ☐ / N/A |
| 34 | Landing product cards / CTAs honest if D runs later | ☐ / N/A |

## F6 — Fail criteria (any one = do not claim polish done)

- Goals visible inside Knows
- Confirm UI looks “saved” before backend apply
- Web voice copy implies background / mobile parity
- Web offers CSV as working
- Clipped composer / sheets on a target device
- Marketing screenshots show old heavy UI or Goals-in-Knows while claiming redesign

---

## Suggested next steps

1. Run **F0** automated tests  
2. Smoke **F1** on one mobile build (Android or iOS)  
3. Smoke **F4** on `/app/` (Chrome + one mobile browser)  
4. Device-specific **F2** / **F3** for the platforms you ship  
5. Only then: **B4/C4** screenshots → optional **Phase D** landing sync  

**Claim rule:** Do not market “redesigned on every platform” until the F tables above are checked for those platforms.
