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
| **D** | Web marketing (`apps/web`) | **DONE** copy/layout/honesty (A111–A115); **A116** screenshot refresh still open (B4/C4) |
| **E** | Flutter web `/app/` | **DONE** code (E1/E3/E4); **E2** needs browser smoke in F |
| **F** | Cross-platform verify | **PARTIAL** — F0 done; **F1 iOS device smoke pass** (2026-07-12) with title-field follow-up; Android/web/F3 still open |

**Claim rule:** Do not market “redesigned on every platform” until Phase F is checked for the platforms named in the claim.

**Out of this file:** background voice (07), Plaid prod smoke (06), Spanish FTUE (09), file→Knows (08), legal substance (10), desktop (11), full rebrand.

---

## Primary paths

| Surface | Paths |
| --- | --- |
| Shared Flutter | `chat_message_bubble.dart`, `chat_transcript.dart`, confirm cards, `saved_memory_tile_shell.dart`, `RexUiTokens`, `clarity_sheet_insets.dart`, Knows/Goals sheets |
| Android / iOS | Safe areas, system bars, sheets, foreground voice chrome |
| Web marketing | `apps/web` Astro — Phase D landed |
| Web app | Flutter `/app/` — `AppCapabilities`, 920px column, honest voice/attach copy, `flutter_bootstrap.js` |

---

# Phase A — Shared Flutter: canon + density — DONE

### A1 Goals out of Knows (A70) — DONE
Knows list/filters force empty plans/goals; empty copy is facts/people/preferences only.

### A2 Chat bubbles lighter (A71–A72) — DONE
User bubbles use `accentSoft` + `textPrimary`. Shared `bubblePaddingH/V`, `messageGap`, `bodyMedium` / height 1.35.

### A3 Knows lean rows (A73–A74) — DONE
Row = title + optional one-line detail + type. Importance only on goals/plans/rules edit+create; people/facts/preferences omit it. Shared `memoryTilePadding*` / `memoryTileRadius`.

### A4 Confirm strip slim (A75) — DONE
Shared `confirmCardPadding` / `confirmCardGap` / `confirmButtonHeight`; no drop shadow; truth-honest confirm/dismiss.

### A5 Shell density (A100) — DONE
Goals reuse Knows tile tokens; composer `composerPadding*` + `bodyMedium`. Finance redesign untouched.

---

# Phase B — Android — code DONE; screenshots open

### B1–B3 — DONE
Safe areas, system UI overlay, sheets, voice chrome. FG service untouched (file 07).

### B4 Play screenshots (A105) — OPEN (manual)
Refresh chat / Knows / Goals / voice captures after device QA. Sync into `apps/web/public/images/app` (A116).

---

# Phase C — iOS — code DONE; screenshots open

### C1–C3 — DONE
Safe areas, denser chrome, sheets/haptics, foreground voice density. Background voice still file 07.

### C4 App Store screenshots (A110) — OPEN (manual)
Same as B4 for iOS; sync with A116 when marketing assets refresh.

---

# Phase D — Web marketing (`apps/web`) — DONE (except screenshot assets)

### D1 Hero / first viewport (A111) — DONE
Hero = brand eyebrow + tagline + lede + primary “Open Clarity on web” + ghost “See how it works” + trust line. Store badges moved to footer CTA only. Device aria-label = mobile preview (honest).

### D2 Product gallery honesty (A112) — DONE
Knows copy: facts/people/events/preferences — **no goals**. New Goals gallery card with `goals.webp`. Softened “everywhere / mobile and web parity” claims. Voice: not “hands-free”; browser-tab honesty. FAQ added: web vs phone capabilities.

### D3 Trust / legal readability (A113) — DONE (presentation)
`hero__actions` / `button--large` / `policy-hero` CSS. Retention table stacks on small screens. Broken PDF link removed. data-deletion scope includes web companion. Privacy waitlist → contact forms.

### D4 Responsive + CTAs (A114–A115) — DONE
Auth pages dark-theme inputs; confirmed/reset copy points to web + phone. App Store pending = “iOS coming soon”. Primary CTA = Open Clarity on web. README deferred list matches `/app/` reality.

### D5 Screenshot sync (A116) — OPEN (manual / B4+C4)
Copy and gallery wiring are honest. **Re-capture** Knows (no Goals), chat density, Goals screen after device QA, then re-run `apps/web/scripts/sync-landing-assets.mjs` and refresh OG if needed. Until then, do not claim “landing screenshots match redesign.”

---

# Phase E — Flutter web `/app/` — code DONE; browser smoke in F

### E1 Capability honesty + layout (A117–A118) — DONE
Honest attach/voice/CSV/Plaid copy. 920px column. Add-account dialog constrained on web.

### E2 Density / keyboard (A119–A120) — OPEN (smoke only)
Shared patterns apply; verify in F4 browser smoke.

### E3–E4 Voice honesty + boot UI (A121–A122) — DONE
Browser-session voice labels. Friendlier boot failure in `flutter_bootstrap.js`.

---

# Phase F — Smoke test list

Check each box on the platforms you claim. Mark **N/A** if that surface is out of launch scope.

## F0 — Automated (quick)

```bash
cd apps/mobile
flutter test test/chat_message_bubble_test.dart test/chat_input_bar_test.dart test/memory_page_test.dart test/voice_clarity_actions_test.dart

cd apps/web
npm run build
```

- [x] Flutter four suites pass (20 tests)
- [x] `apps/web` `npm run build` passes (Phase D)

## F1 — Canon + density (every Flutter surface you ship)

| # | Check | Android | iOS | `/app/` |
| --- | --- | :---: | :---: | :---: |
| 1 | Knows has **no** Goals / plans group or plan tiles | ☐ | ☑ | ☐ |
| 2 | Knows empty copy does **not** mention goals | ☐ | ☑ | ☐ |
| 3 | Goals tab still shows plans + Open Threads | ☐ | ☑ | ☐ |
| 4 | Chat: soft user bubbles; readable light **and** dark | ☐ | ☑ | ☐ |
| 5 | Chat: bubbles not overly padded; transcript feels dense but readable | ☐ | ☑ | ☐ |
| 6 | Knows rows: title + optional one line + type; no importance/date chrome in list | ☐ | ☑ | ☐ |
| 7 | Importance only on goals/plans/rules (not people/facts/preferences); dates OK where shown | ☐ | ☑ | ☐ |
| 8 | Confirm card: slim, no heavy shadow; Confirm/Dismiss obvious | ☐ | ☑* | ☐ |
| 9 | Confirm → item appears in Knows or Goals; Rex does not claim saved before confirm | ☐ | ☑ | ☐ |
| 10 | Goals tiles match Knows density (not card-heavy) | ☐ | ☑ | ☐ |

\*iOS F1 device smoke 2026-07-12: pass. Editable Title field was oversized (`titleSmall`) — fixed in compact confirm density follow-up. Known non-blockers: Knows vs Goals/Thread propose routing; Assistant still felt web-heavy → compact M1/M2 density track.

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
| 16 | Notch / Dynamic Island / home indicator: chat send, attach sheet, Knows edit, voice panel not clipped | ☐ re-smoke after compact density |
| 17 | Assistant tabs + header feel denser; back swipe still works | ☐ re-smoke (header denser on compact) |
| 18 | Sheets: drag-to-dismiss + grabber; confirm/dismiss light haptic | ☐ |
| 19 | Foreground voice chrome matches chat density | ☐ |
| 20 | Do **not** expect background walk-and-talk (file 07) | ☐ noted |

**Re-smoke after this density ship (device):** F1 #8 Title field ≈ Details size; F3 #16–17 header/composer not clipped. Then C4 screenshots → A116.

## F4 — Flutter web `/app/`

| # | Check | Pass |
| --- | --- | :---: |
| 21 | Wide desktop: finance tabs ~1200px, assistant ~900px, profile ~720px (not full ultrawide bleed) | ☐ |
| 22 | Bottom centered dock present (≥800px); Digit1–5 shortcuts switch tabs; hover tooltips | ☐ |
| 23 | No drag-handle sheets on wide: category manage, profile appearance/language, memory create/edit → centered dialogs | ☐ |
| 24 | Dashboard: overview+insights row; charts in 2-col grid without accordion taps | ☐ |
| 25 | Accounts: tile grid (no hollow stretched rows); Budgets: compact period control + side chart | ☐ |
| 26 | Profile: inline theme segmented control + language dropdown (no chevron→sheet on desktop) | ☐ |
| 27 | Assistant wide: Chats list + Chat split pane; chat column capped ~760 | ☐ |
| 28 | Visible scrollbar thumbs; snackbars clear of dock; mouse click cursors on tiles | ☐ |
| 29 | Mic tooltip / active voice hint: browser / keep tab open | ☐ |
| 30 | Attach tooltip: file-oriented | ☐ |
| 31 | Add account: CSV disabled with mobile-only copy; Plaid available if web Link works | ☐ |
| 32 | Chat send + streaming reply scroll OK (desktop Chrome) | ☐ |
| 33 | Mobile Safari (or narrow Chrome): composer not permanently covered; can send | ☐ |
| 34 | Confirm strip usable; truth-honest after confirm | ☐ |
| 35 | Knows / Goals density readable on wide + narrow | ☐ |
| 36 | Boot: “Loading Clarity…” then app (not stuck blank) | ☐ |
| 37 | Optional: bad asset path → friendly boot error | ☐ |
| 38 | Widget tests: breakpoints + adaptive overlay + dock at 1280/1920 (`desktop_layout_foundation_test.dart`) | ☐ |

## F5 — Marketing / store

| # | Check | Pass |
| --- | --- | :---: |
| 31 | Landing hero: one primary CTA (“Open Clarity on web”); stores in footer | ☐ |
| 32 | Knows gallery copy has **no** goals; Goals is its own card | ☐ |
| 33 | Voice / web FAQ do not claim full mobile parity | ☐ |
| 34 | App Store badge shows “iOS coming soon” when URL empty | ☐ |
| 35 | Privacy / data-deletion readable at ~375px; no broken PDF | ☐ |
| 36 | Screenshots match shipping density (after B4/C4 refresh) | ☐ / N/A until recapture |

## F6 — Fail criteria (any one = do not claim polish done)

- Goals visible inside Knows (app or landing copy)
- Confirm UI looks “saved” before backend apply
- Web voice copy implies background / mobile parity
- Web offers CSV as working
- Clipped composer / sheets on a target device
- Marketing screenshots show Goals-in-Knows or old heavy UI while claiming redesign

---

## Suggested next steps

1. Re-smoke **F1 #8** on iOS after compact confirm title/density (Title field should match Details size).
2. Complete **F3** iOS notch/sheet/voice chrome checks on device.
3. Smoke **F2** Android + **F4** `/app/` when claiming those surfaces.
4. **C4/A116** screenshot refresh after density looks right — do not claim redesign screenshots until then.
5. Optional later: Knows-vs-Goals propose routing (parking lot); finance mobile density is out of this Assistant track.

**Mobile density track (post-F1 iOS):** compact confirm/composer tokens + denser Assistant header landed in `RexUiTokens` / confirm cards / `assistant_top_surface.dart`. Wide `/app/` keeps prior roomier defaults.
