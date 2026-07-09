# 02 — Cross-Platform UI Upgrade (Chat, Knows, Native Polish, Web)

**Covers:** Make Clarity feel lighter and more practical across **Android**, **iOS**, and **web** — without a full redesign or a second design system. Shared Flutter density/canon work first; then platform-specific polish; then a dedicated web track (marketing site + Flutter companion at `/app/`).

**Canon:** `CLARITY_RULES.md` — Saved Memory in Knows; Goals in Goals; keep them separate. Marketing and UI must not overclaim platform parity (see file 07 matrix / file 09 honesty).

**Primary paths**

| Surface | Paths |
| --- | --- |
| Shared Flutter | `chat_message_bubble.dart`, `chat_transcript.dart`, `clarity_action_cards_strip.dart` / person card, `saved_memory_group_list.dart`, `saved_memory_tile_shell.dart`, `RexUiTokens`, `lib/theme/*`, Knows/Goals sheets |
| Android | Material nav/system bars, FG voice chrome, edge-to-edge / gesture nav insets, Play-facing screenshots |
| iOS | Safe areas / Dynamic Island / home indicator, Cupertino-feel sheets where already used, foreground voice chrome, App Store screenshots |
| Web marketing | `apps/web` Astro (`index.astro`, `global.css`, `site.ts`, product screens) |
| Web app | Flutter web PWA at `/app/` (`AppCapabilities.isWeb`, `web_centered_dialog.dart`, chat/voice capability gates, deploy scripts) |

---

## Track map (how to execute)

```text
Phase A — Shared canon + density (Android + iOS + Flutter web inherit)
Phase B — Android-specific polish
Phase C — iOS-specific polish
Phase D — Web marketing polish (apps/web)
Phase E — Web companion app polish (Flutter /app/)
Phase F — Cross-platform verify + screenshot honesty
```

Work **A before B/C** (shared tokens/widgets). **D and E are independent** of B/C but should not contradict A. **F last.**

Saturday note: Phase A (especially Goals-out-of-Knows) is the highest-value slice. B–E are product-feel; not truth/security blockers.

---

# Phase A — Shared Flutter: canon + density

Applies to Android, iOS, and Flutter web unless a later phase overrides.

## A1 — Canon: Goals out of Knows

### Issue: Goals group rendered inside Knows (A70)

- **Severity:** High (product clarity)
- **Platforms:** All Flutter surfaces
- **Why it matters:** Same goals in Knows and Goals; violates “clearly separate Saved Memory and Goals.”
- **Estimated effort:** Small
- **Brief fix suggestion:** Remove `MemoryGroup.goals` / plan tiles from `SavedMemoryGroupList` and Knows filters that only exist to surface plans. Keep create/edit on Goals tab (and chat confirm → Goals refresh). Update Knows empty-state copy if it mentions goals. Re-check web marketing Knows screenshot/copy (Phase D) so it does not show Goals inside Knows.

## A2 — Chat bubbles: lighter density

### Issue: Solid teal user bubbles feel heavy (A71)

- **Severity:** Medium
- **Platforms:** All Flutter
- **Why it matters:** Dense filled bubbles dominate the transcript; Grok-like UIs use muted text + slight tint.
- **Estimated effort:** Small
- **Brief fix suggestion:** In `chat_message_bubble.dart` / `RexUiTokens.userBubble`, replace solid teal fill with a soft tint (low-alpha teal or elevated surface). Keep readable contrast in light and dark. Preserve streaming / expandable assistant behavior.

### Issue: Bubble and transcript spacing too large (A72)

- **Severity:** Medium
- **Platforms:** All Flutter
- **Why it matters:** Large padding + `bodyLarge` + generous list gaps make short turns feel like cards.
- **Estimated effort:** Small
- **Brief fix suggestion:** Tighten bubble padding; reduce inter-message spacing in `chat_transcript.dart` (and voice interim spacing if needed). Prefer `RexUiTokens` / `ClaritySpacing` tweaks over one-off magic numbers.

## A3 — Knows: practical rows, details on tap

### Issue: Knows tiles show too much chrome (A73)

- **Severity:** Medium
- **Platforms:** All Flutter
- **Why it matters:** Title + long subtitle + type · importance · date + icons makes scanning hard.
- **Estimated effort:** Medium
- **Brief fix suggestion:** Default row = **title + one meta line**. Move importance and dates into the edit sheet. Keep overflow / archive reachable.

### Issue: Knows list still feels card-heavy (A74)

- **Severity:** Low–Medium
- **Platforms:** All Flutter
- **Why it matters:** Large radius + thick surfaces read as dashboard cards, not a memory list.
- **Estimated effort:** Small
- **Brief fix suggestion:** Slightly reduce tile padding/radius in the shared tile shell; avoid nested “card in card.” Do not invent a second design system.

## A4 — Confirm strip slim-down

### Issue: Confirm action strip padding is heavy (A75)

- **Severity:** Low–Medium
- **Platforms:** All Flutter (chat + voice dialogs)
- **Why it matters:** Pending save cards compete with the transcript.
- **Estimated effort:** Small
- **Brief fix suggestion:** Reduce padding in confirm strip / person card shells; keep confirm/reject obvious and truth-honest (no visual “success” without applied).

## A5 — Shared shell density (optional stretch)

### Issue: Assistant / finance shells still feel dashboard-heavy (A100)

- **Severity:** Low–Medium
- **Platforms:** All Flutter
- **Why it matters:** Chat/Knows polish can still feel heavy next to dense Dashboard/Goals chrome.
- **Estimated effort:** Medium
- **Brief fix suggestion:** Light pass on Goals list density and chat composer chrome only — same tokens, no rebrand. Stop before touching full finance redesign.

---

# Phase B — Android-specific polish

Shared Phase A lands first; then verify and tune Android.

## B1 — System UI and navigation

### Issue: Edge-to-edge / gesture nav insets inconsistent (A101)

- **Severity:** Medium
- **Platform:** Android
- **Why it matters:** Content or confirm strip can sit under gesture bars or status bar on modern Android.
- **Estimated effort:** Small–Medium
- **Brief fix suggestion:** Audit chat, Knows, Goals, voice overlay, and confirm strip with `SafeArea` / `MediaQuery.padding` on gesture-nav devices. Prefer one consistent inset pattern; do not add artificial delays.

### Issue: Status / navigation bar contrast vs theme (A102)

- **Severity:** Low–Medium
- **Platform:** Android
- **Why it matters:** Light/dark theme switches can leave icons unreadable on system bars.
- **Estimated effort:** Small
- **Brief fix suggestion:** Align `SystemChrome` / `SystemUiOverlayStyle` with `ThemeMode` (Profile theme control). Spot-check Material 3 `NavigationBar` if used on main shell.

## B2 — Material feel without a redesign

### Issue: Sheets and ripples feel generic or heavy on Android (A103)

- **Severity:** Low
- **Platform:** Android
- **Why it matters:** After density pass, Android should still feel native (ripples, scrim, sheet height), not iOS-copied.
- **Estimated effort:** Small
- **Brief fix suggestion:** Keep Material components; tune bottom-sheet initial size and scrim for Knows edit / attach / confirm. No Cupertino swap on Android.

## B3 — Voice chrome on Android

### Issue: Voice overlay density competes with FG-service UX (A104)

- **Severity:** Medium
- **Platform:** Android
- **Why it matters:** Android is the strongest walk-and-talk surface; heavy interim UI fights the product promise.
- **Estimated effort:** Small
- **Brief fix suggestion:** Apply A2/A4 spacing to voice interim + confirm dialogs. Do **not** change FG service / background behavior here (file 07 owns that). Visual polish only.

## B4 — Android store / QA visuals

### Issue: Play screenshots and device QA lag behind polish (A105)

- **Severity:** Low (marketing)
- **Platform:** Android
- **Why it matters:** Store and landing images can show pre-density UI or Goals-in-Knows.
- **Estimated effort:** Small
- **Brief fix suggestion:** After A+B, refresh key Play screenshots (chat, Knows, Goals, voice). Feed updated assets to Phase D if landing uses the same captures.

---

# Phase C — iOS-specific polish

## C1 — Safe areas and Apple chrome

### Issue: Notch / Dynamic Island / home indicator clipping (A106)

- **Severity:** Medium
- **Platform:** iOS
- **Why it matters:** Chat composer, confirm strip, and voice overlay are easy to clip on notched devices.
- **Estimated effort:** Small–Medium
- **Brief fix suggestion:** Device QA on recent iPhone: chat send, attach sheet, person confirm card, Knows edit sheet, voice panel. Fix with shared safe-area patterns — no platform-only hacks that break Android.

### Issue: Large title / nav bar density mismatch (A107)

- **Severity:** Low
- **Platform:** iOS
- **Why it matters:** After bubble density pass, oversized nav chrome still feels “cardy.”
- **Estimated effort:** Small
- **Brief fix suggestion:** Tighten Assistant / Knows / Goals app-bar spacing where Flutter controls it; keep iOS back/swipe expectations intact.

## C2 — Sheets and haptics

### Issue: Edit / attach sheets feel Android-ported on iPhone (A108)

- **Severity:** Low–Medium
- **Platform:** iOS
- **Why it matters:** Users expect familiar sheet grabbers and dismiss behavior.
- **Estimated effort:** Small–Medium
- **Brief fix suggestion:** Where sheets already exist, ensure drag-to-dismiss and top padding work on iOS; optional light haptic on confirm/reject **only if** already patterned elsewhere — do not invent a haptic system.

## C3 — Voice chrome on iOS (foreground)

### Issue: Foreground voice UI heavier than chat after polish (A109)

- **Severity:** Medium
- **Platform:** iOS
- **Why it matters:** iOS launch story is foreground voice; UI should feel as light as chat.
- **Estimated effort:** Small
- **Brief fix suggestion:** Match voice interim/confirm density to Phase A. Background walk-and-talk remains file 07 (capability honesty), not this file.

## C4 — App Store / QA visuals

### Issue: App Store screenshots and landing assets stale (A110)

- **Severity:** Low (marketing)
- **Platform:** iOS
- **Why it matters:** Same as Android — honesty and polish must match shipping UI.
- **Estimated effort:** Small
- **Brief fix suggestion:** Refresh chat / Knows / Goals / voice captures post Phase A+C; sync with Phase D.

---

# Phase D — Web marketing site (`apps/web`)

Dedicated track. This is **not** Flutter. Scope: landing, trust pages, product storytelling. Do **not** build an authenticated web dashboard here (README deferred list stays deferred).

## D1 — Visual system and first viewport

### Issue: Landing hero / product story feels generic or cluttered (A111)

- **Severity:** Medium
- **Platform:** Web marketing
- **Why it matters:** `goclarity.app` is the trust + download surface; weak branding or dashboard-like first viewport hurts conversion and Plaid review trust.
- **Estimated effort:** Medium
- **Brief fix suggestion:** In `index.astro` + `global.css`, keep **one composition** in the first viewport: brand, one headline, one short lede, one CTA group, one dominant device visual. Avoid packing stats, FAQs, and multi-screen grids into the hero. Prefer expressive type over default Inter-only if changing fonts — stay coherent with existing teal/dark system; no purple-glow AI cliché redesign.

### Issue: Product screen gallery overclaims or shows wrong canon (A112)

- **Severity:** High (honesty) / Medium (UI)
- **Platform:** Web marketing
- **Why it matters:** Copy like “mobile and web” on Dashboard, or Knows showing goals, trains wrong expectations.
- **Estimated effort:** Small–Medium
- **Brief fix suggestion:** Update `productScreens` / `site.ts` copy to match real capabilities (web companion limits; Goals not inside Knows). Replace screenshots after mobile polish so chat density and Knows rows match shipping UI.

## D2 — Trust and legal page readability

### Issue: Privacy / security / terms pages are dense walls of text (A113)

- **Severity:** Low–Medium
- **Platform:** Web marketing
- **Why it matters:** Trust pages are part of launch polish; unreadable legal hurts Plaid and users.
- **Estimated effort:** Small
- **Brief fix suggestion:** Improve typography rhythm and section headers in shared layout/CSS only — **do not** rewrite legal substance here (file 10 owns subprocessors/policy content). Polish presentation, not claims.

## D3 — Responsive and performance

### Issue: Landing breaks or feels heavy on small phones (A114)

- **Severity:** Medium
- **Platform:** Web marketing
- **Why it matters:** Many users hit the site on mobile browsers before installing.
- **Estimated effort:** Small–Medium
- **Brief fix suggestion:** QA 375–430px widths: hero stack, CTAs, device image, FAQ. Compress/lazy-load non-hero images; keep hero image eager. Preserve Cloudflare deploy rules (do not break `/app/` Flutter assets — see web README).

### Issue: Download / login CTAs unclear across platforms (A115)

- **Severity:** Medium
- **Platform:** Web marketing
- **Why it matters:** “Web · iPhone · Android” eyebrow must match real store links and `/app/` companion behavior.
- **Estimated effort:** Small
- **Brief fix suggestion:** Audit `DownloadActions.astro` + `authLinks`: honest labels (Open web app vs Get on iPhone/Android). Hide or soft-label missing store links; never imply full parity.

## D4 — Marketing ↔ product visual sync

### Issue: Landing screenshots diverge from app after polish (A116)

- **Severity:** Medium
- **Platform:** Web marketing
- **Why it matters:** Users install and feel bait-and-switched.
- **Estimated effort:** Small (process) + asset work
- **Brief fix suggestion:** After Phases A–C (and E if `/app/` chrome changes), refresh `public/images/app/*` and alt text. Checklist item in Phase F.

---

# Phase E — Web companion app (Flutter at `/app/`)

Dedicated track for the **authenticated Flutter web** experience. Companion, not mobile parity.

## E1 — Capability-honest UI

### Issue: Web UI offers actions that cannot work (A117)

- **Severity:** High (trust)
- **Platform:** Flutter web
- **Why it matters:** Attach/CSV/background-voice/Plaid affordances that fail or lie break trust.
- **Estimated effort:** Medium
- **Brief fix suggestion:** Audit chat attach, voice entry, CSV import, Plaid connect against `AppCapabilities`. Hide or replace with honest empty/disabled copy (coordinate stale Plaid string with file 06). No fake success.

### Issue: Web layout feels like a stretched phone (A118)

- **Severity:** Medium
- **Platform:** Flutter web
- **Why it matters:** Desktop/laptop users get an awkward narrow column or full-bleed mobile chrome.
- **Estimated effort:** Medium
- **Brief fix suggestion:** Use existing `web_centered_dialog.dart` patterns; add a simple max-width content column for chat/Knows/Goals on wide viewports. Do **not** build a multi-pane desktop IDE. Keep one composition per view.

## E2 — Chat / Knows density on web

### Issue: Phase A density not verified on Flutter web (A119)

- **Severity:** Medium
- **Platform:** Flutter web
- **Why it matters:** Pointer/hover and wide screens change how heavy bubbles/tiles feel.
- **Estimated effort:** Small
- **Brief fix suggestion:** After A, smoke `/app/` chat + Knows + confirm cards in Chrome/Safari. Fix web-only overflow/scroll quirks; keep shared widgets.

### Issue: Keyboard and scroll quirks on web chat (A120)

- **Severity:** Medium
- **Platform:** Flutter web
- **Why it matters:** Composer covered by keyboard or scroll jump makes web companion feel broken.
- **Estimated effort:** Medium
- **Brief fix suggestion:** QA mobile Safari + desktop Chrome: send, attach (if enabled), streaming reply, confirm strip. Fix inset/scroll only with proper Flutter web patterns — no timer hacks.

## E3 — Web voice honesty (UI only)

### Issue: Voice UI on web overpromises (A121)

- **Severity:** Medium
- **Platform:** Flutter web
- **Why it matters:** No background voice; mic requires secure context; JWT-in-URL is a security issue (file 04/07).
- **Estimated effort:** Small (UI) 
- **Brief fix suggestion:** If voice is offered on web, label it as browser session / foreground-only. If disabled, show clear companion copy pointing to mobile. Do not polish a broken path into looking “complete.”

## E4 — Boot and deploy UX

### Issue: “Loading Clarity…” / blank boot still possible after bad deploy (A122)

- **Severity:** High when it happens
- **Platform:** Flutter web
- **Why it matters:** Marketing HTML served as JS leaves users stuck; known Cloudflare footgun.
- **Estimated effort:** Small (ops + light UI)
- **Brief fix suggestion:** Keep deploy checklist from `apps/web/README.md` / deploy scripts. Optional: friendlier boot failure message if assets fail to load (no fake “you’re in”). Not a redesign.

---

# Phase F — Cross-platform verify

### Issue: Visual + canon + honesty smoke (A76 / A123)

- **Severity:** Medium (gate for claiming UI polish)
- **Platforms:** Android, iOS, web marketing, Flutter web
- **Why it matters:** Density and platform tweaks can hurt contrast, clip controls, or leave marketing lying.
- **Estimated effort:** Medium (manual + focused tests)
- **Brief fix suggestion:**

| Check | Android | iOS | Web marketing | Flutter `/app/` |
| --- | :---: | :---: | :---: | :---: |
| Knows has no Goals group | ☐ | ☐ | screenshots/copy ☐ | ☐ |
| Chat density readable light/dark | ☐ | ☐ | — | ☐ |
| Confirm strip usable + truth-honest | ☐ | ☐ | — | ☐ |
| Safe areas / system bars OK | ☐ | ☐ | responsive ☐ | scroll/keyboard ☐ |
| Voice chrome matches density | ☐ | ☐ foreground | — | honest label/hidden ☐ |
| Store/landing screenshots updated | ☐ | ☐ | ☐ | optional |
| Capability copy honest | Plaid/CSV/voice | Plaid/voice | CTAs + product cards | `AppCapabilities` |

Run existing Flutter bubble/Knows widget tests; adjust expectations if layout assertions break. Spot-check landing build (`npm run build`) and `/app/` boot after deploy script.

---

## Out of scope (do not pull into this file)

- Full rebrand, glassmorphism, Material 3 rewrite, or new illustration system
- Authenticated web dashboard / billing admin (still deferred per `apps/web` README)
- Spanish FTUE / marketing copy localization (file 09) — this file may add EN strings; ES in 09
- File import → Knows/Goals product work (file 08)
- Voice hang / background iOS implementation (file 07)
- Plaid production smoke and finance ops (file 06)
- Privacy policy substance / subprocessors (file 10)
- Backend memory intent / location clarifier (code fix; not UI)
- Desktop macOS/Windows as a launch target (file 11)

---

## Suggested execution order

1. **A1** Goals out of Knows (canon win)  
2. **A2–A4** shared density  
3. **B** + **C** device QA and platform fixes in parallel if two people  
4. **E1** capability-honest web app (trust) before deep web density  
5. **D** landing copy/screenshots after mobile looks right  
6. **E2–E4** web companion polish  
7. **F** full matrix  

**Claim rule:** Do not market “redesigned on every platform” until F’s table is checked for the platforms named in the claim.
