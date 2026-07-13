# 13 — Native Phone UI Remodel (iPhone-first, Android-ready tokens)

**Covers:** Remodel the full native compact Flutter UI so it feels designed for a phone — full-bleed, consistent, modern — without changing wide Flutter `/app/` (user-loved).

**Canon:** `MASTER_PLAN.md` · `CLARITY_RULES.md` · `PROJECT_STRUCTURE.md`  
**Related:** [`02_Chat_and_Knows_UI_Upgrade.md`](02_Chat_and_Knows_UI_Upgrade.md) Phase F3 (re-smoke notes updated in **Phase F** of this file only).

**Status:** Phase A–E done (tokens + finance + Chats + composer + Knows/Goals/Overview/Profile gutters). Phase F remaining — do not ship “redesigned phone UI” claims until Phase F passes.

---

## Mission

Phone-only remodel: `RexUiTokens.isNativeCompactChrome` = `!kIsWeb && width < 800`.

| Must | Must not |
| --- | --- |
| Edge-to-edge phone width for finance modules | Regress wide/desktop `/app/` visual layout |
| Shared “native compact” tokens (Android later) | Barge-in; background voice (07) |
| One spacing / type / radius / list-row system | Finance IA rewrite (account/budget *product* model) |
| Grok / iMessage-like composer (no field fill/shadow) | Web marketing (`apps/web`) changes |
| Dense Cursor-sidebar-like Chats rows | One-off padding hacks / god-file growth |
| Keep files ≤ ~400 lines (extract first) | Silent nav changes without keeping Chats history ≤1 tap away |

**Open to change (phone chrome / IA):** Bottom-nav **may** add a sixth tab or restructure tabs. Chats sub-tab **may** be removed or relocated as long as conversation history stays easily accessible (top affordance, drawer, dedicated tab, or Assistant entry). Prefer the cleanest phone pattern; propose options when touching shell/Assistant — don’t block Phase A layout tokens on nav debates.

**North star:** Grok / ChatGPT mobile for chat & chrome; Cursor sidebar for chat-list density. Identity via spacing, type, list density, calm surfaces — not louder fills.

---

## Audit findings (pre-code)

### Gate already exists

| Helper | Meaning |
| --- | --- |
| `isCompactChrome` | width &lt; 800 (includes narrow web) |
| `isNativeCompactChrome` | `!kIsWeb && isCompactChrome` — **phone gate** |
| `clarityLayoutMediumBreakpoint` | `800` |

Wide `/app/` must keep using desktop/wide branches only.

### Pain 1 — Finance “letterbox” (root cause)

Stacked horizontal inset on phone charts (example: “Six-month spend trend”):

| Layer | Source | Phone H inset (approx.) |
| --- | ---: | ---: |
| Shell clamp | `ShellContentConstraints` → `clarityClampedContentWidth(..., gutter: 24)` | **24 + 24** screen letterbox even on iPhone |
| Page gutter | `financial_dashboard_shell` `SliverPadding` `desktop ? 24 : 16` | **16 + 16** |
| Group chrome | `_DashboardCollapsibleChartGroup` `childrenPadding` / card pad **20** | **20 + 20** |
| Chart panel | `_DashboardChartPanel` pad **18** | **18 + 18** |
| **Total to plot** | | **~78px per side** on a ~390pt phone |

Also: cards still use desktop-ish inner padding (`22–28`) and `ClarityRadius.card` (18) as floating web panels. Overview card already slightly denser on compact (`16`), but charts do not.

**Same class of problem:** Accounts (`16–32` pads), Budgets (`16` page + nested ExpansionTile `16`), month detail (`24`).

### Pain 2 — Composer pill fill

| Fact | Location |
| --- | --- |
| Native compact wraps field in elevated pill `DecoratedBox` | `chat_input_bar.dart` when `usesFilledComposerField` |
| Flag is **true** for native compact | `RexUiTokens.usesFilledComposerField` |
| TextField itself is already `filled: false` | good — remove outer fill, not fight InputDecoration |

Target: Grok / web-adapted / iMessage-like — larger type area, **no** background fill or inner shadow inside the text field. Wide composer stays unchanged.

### Pain 3 — Chats list oversized on phone

| Fact | Implication |
| --- | --- |
| Dense tile path is `compact: true` | title-only row (Cursor-like) |
| Phone Chats tab uses `compactSidebar: false` (default) | **card layout**: glyph + `titleSmall` + **2-line** preview + large pads |
| Dense mode only wired for desktop sidebar | `assistant_screen.dart` `compactSidebar: true` |
| Title clamp exists (`kConversationTitleMaxLength = 48`) | keep; tighten display if needed |
| Search pad `16` vs list row outer pads | misalignment vs dense list |

Fix class: phone Chats must use **dense list-row** tokens (title + one preview line), not the web/card tile.

### Pain 4 — Cross-app inconsistency

Hardcoded `16/20/24/28` pads scattered across finance, assistant, profile. `ClaritySpacing` scale exists but **no shared page/module/list helpers**. `RexUiTokens` has assistant chrome only. No shared type-scale helpers for list title / preview / section label.

---

## Proposed shared token table

Add a **native-compact layout system** (name TBD: `ClarityNativeLayout` / extend `clarity_breakpoints.dart` + thin helpers). Consume via `isNativeCompactChrome`; wide paths ignore these values.

| Token | Native compact (`!kIsWeb && <800`) | Wide / web `/app/` (unchanged) | Role |
| --- | ---: | ---: | --- |
| `pageGutter` | **10** (clamp 8–12) | keep `24` desktop shell gutter | Outer page inset |
| `shellContentGutter` | **0** | `clarityDesktopContentGutter` (24) | `ShellContentConstraints` clamp — **fix phone letterbox** |
| `moduleEdgeInset` | **0** (full-bleed modules) or **8** if hairline margin needed | N/A / keep nested cards | Chart/section modules to screen edge |
| `sectionGap` | **12–16** | keep `_sectionGap` 20 | Vertical rhythm between modules |
| `cardPadding` | **12–14** | keep 18–24 | Inner module padding (single layer) |
| `cardRadius` | **12** (`ClarityRadius.medium`) | keep `ClarityRadius.card` (18) | Less “floating panel” |
| `listRowPaddingH` | **10–12** | keep 16 | Search + list share this |
| `listRowPaddingV` | **8–10** | keep 12 | Dense rows |
| `listRowGap` | **0–2** | keep 8 | Between rows |
| `listTitleMaxChars` | **40** (display; storage can stay 48) | 48 | Ellipsis before overwhelm |
| `listPreviewMaxLines` | **1** | 2 (sidebar may stay title-only) | Dense phone rows |
| `listTitleStyle` | `bodyMedium` w600–700 | `titleSmall` / sidebar body | Same hierarchy everywhere |
| `listPreviewStyle` | `bodySmall` / muted | `bodyMedium` | Secondary line |
| `sectionLabelStyle` | `labelLarge` w600, muted | existing | Finance + assistant sections |
| `composerFieldFill` | **false** | false | Kill pill fill |
| `composerFieldMinHeight` | **44–48** | existing | Comfortable tap/type |
| `composerFieldPaddingV` | **10–12** | keep current wide | Readable height without fill |
| `composerChromePadH` | **8–10** | keep | Align with page gutter |
| `bubbleSideInset` | keep 16 | keep 36 | Already native-aware |

**Invariant:** Prefer **one** horizontal inset layer on phone (page **or** module edge), not page + group card + inner panel all at web sizes.

**Suggested API shape (implement in Phase A):**

```dart
// Pseudocode — phone-only; wide callers never read these.
abstract final class ClarityNativeLayout {
  static bool active(BuildContext c) => RexUiTokens.isNativeCompactChrome(c);
  static double pageGutter(BuildContext c);
  static double shellContentGutter(BuildContext c); // 0 native, 24 else
  static EdgeInsets pagePadding(BuildContext c, {double top, double bottom});
  static double sectionGap(BuildContext c);
  static EdgeInsets cardPadding(BuildContext c);
  static double cardRadius(BuildContext c);
  static EdgeInsets listRowPadding(BuildContext c);
  static int listTitleMaxChars(BuildContext c);
  static int listPreviewMaxLines(BuildContext c);
  static TextStyle? listTitle(BuildContext c, {bool selected});
  static TextStyle? listPreview(BuildContext c);
}
```

Keep `RexUiTokens` for assistant chrome; **layout gutters live in core/theme** so finance can import without pulling rex concerns the wrong way (or: put layout tokens in `core/layout/`, leave colors in Rex).

---

## Phased execution

Work **A → F**. One PR/commit theme per phase. Stop and re-smoke iPhone after B and D.

### Phase A — Native mobile layout system (tokens only + shell gutter fix)

**Goal:** Shared helpers; no visual regression on wide; first real fix = shell content gutter `0` on native compact.

| Step | Work | Files (start here) |
| --- | --- | --- |
| A1 | Add `ClarityNativeLayout` (or equivalent) with table above | `apps/mobile/lib/core/layout/clarity_native_layout.dart` ✅ |
| A2 | `clarityClampedContentWidth` / `ShellContentConstraints`: gutter **0** when native compact; **24** otherwise | `clarity_breakpoints.dart`, `finance_content_constraints.dart` ✅ |
| A3 | Wire helpers; do **not** restyle all screens yet | Export from layout; `RexUiTokens.isNativeCompactChrome` → `ClarityNativeLayout.active` ✅ |
| A4 | Widget tests: compact native vs wide vs narrow-web | `test/native_layout_tokens_test.dart` (+ `@TestOn('browser')` web file) ✅ |

**Acceptance A:**

- [x] On 390×844 **non-web** test, `shellContentGutter == 0` and content width ≈ viewport
- [x] On 1280 wide, gutter/max-width behavior unchanged
- [x] Narrow **web** compact does **not** get native full-bleed (gate = `!kIsWeb`)
- [x] No finance/assistant visual rewrite beyond shell clamp (optional: dashboard still 16 until B)

**Extract rule:** If touching `financial_dashboard_shell.dart` (~550+) or `conversation_list_page.dart` (~830), extract before adding logic.

---

### Phase B — Finance full-bleed remodel

**Order:** Dashboard → Accounts → Budgets (month detail if same tokens).

| Step | Work |
| --- | --- |
| B1 | Dashboard: `SliverPadding` → `pageGutter` / `moduleEdgeInset`; collapse **double card** (group + `_DashboardChartPanel`) to **one** surface on native |
| B2 | Chart/cards/summary: use `cardPadding` + `cardRadius` + `sectionGap` on native only |
| B3 | Accounts list/header/tiles: same page gutter; kill `32` empty-state side pads on phone |
| B4 | Budgets: page + expansion children use tokens; no nested 16+16 letterbox |
| B5 | Keep wide row layouts (`if (wide) Row(...)`) untouched |

**Primary files:**

- `financial_dashboard_shell.dart`, `financial_dashboard_charts.dart`, `financial_dashboard_cards.dart`, `financial_dashboard_summary_sections.dart`, `financial_dashboard_transaction_lists.dart`
- `account_selection_screen.dart`, `accounts_header.dart`, related tiles
- `budgets_screen_widgets.dart`, `budget_category_list.dart`

**Acceptance B:**

- [x] iPhone: chart modules use near-full phone width (≈ pageGutter 8–12 only; no ~80px side void)
- [x] Single visual chrome layer around charts on phone
- [x] Wide `/app/` dashboard screenshots/tests unchanged
- [x] No IA / nav changes

---

### Phase C — Chats list + search alignment + dense rows

| Step | Work |
| --- | --- |
| C1 | Phone Chats: drive **dense list-row** via `isNativeCompactChrome` (not only `compactSidebar`) |
| C2 | Row = **title (1 line, maxChars + ellipsis) + preview (1 line)** + quiet timestamp; no oversized card/glyph on phone |
| C3 | Search field horizontal pad **==** list row pad |
| C4 | Keep desktop sidebar `compactSidebar` behavior on wide. On phone: dense rows; Chats entry may stay as sub-tab **or** move (drawer / top control / own tab) — history must remain one tap away |

**Primary files:**

- `conversation_list_page.dart` (+ extracts `conversation_list_chrome.dart`, `conversation_list_actions.dart`)
- `conversation_history_widgets.dart` (+ extracts `conversation_history_tile.dart`, `conversation_history_labels.dart`, `conversation_history_filters.dart`)
- Existing tests: `conversation_history_tile_test.dart`, `conversation_history_widgets_test.dart`

**Acceptance C:**

- [x] Density comparable to Cursor sidebar (tight rows)
- [x] Titles never overwhelm (maxChars + ellipsis)
- [x] Search aligned with list
- [x] Wide sidebar unchanged

---

### Phase D — Chat composer + transcript consistency

| Step | Work |
| --- | --- |
| D1 | Set `usesFilledComposerField` → **false** (or delete fill branch); no field fill/shadow |
| D2 | Raise comfortable type height via `composerFieldPaddingV` / min height tokens (not pill fill) |
| D3 | Align composer chrome H with `pageGutter` / list gutters |
| D4 | Transcript: keep bubble inset; ensure padding matches system (no new nested chrome) |

**Primary files:**

- `rex_ui_tokens.dart`, `chat_input_bar.dart` (+ extract `chat_input_bar_attachment.dart`), `chat_transcript.dart`
- Tests: `chat_input_bar_test.dart`, `rex_ui_tokens_compact_test.dart`

**Acceptance D:**

- [x] Composer comfortable to type; no inner fill/shadow on phone
- [x] Wide web composer unchanged
- [x] Confirm strip still inline on native (no auto dialog regression)

---

### Phase E — Knows / Goals / Overview / Profile onto same system

| Step | Work |
| --- | --- |
| E1 | Knows list / headers → `pageGutter` + list-row tokens (keep tile shell; adjust outer pads) |
| E2 | Goals / Open Threads shared empty/list chrome |
| E3 | Assistant overview |
| E4 | Profile / usage summary |

**Primary files:**

- `memory_page.dart` (+ extract `memory_page_actions.dart`), `memory_page_header_widgets.dart`, `saved_memory_tile_shell` (outer pads)
- `accountability_page.dart` / `accountability_page_shared.dart` (+ Goals form moved into shared)
- `assistant_overview_page.dart`, `assistant_overview_widgets.dart`, `assistant_top_surface.dart`
- `profile_screen.dart`, `profile_screen_widgets.dart`, `usage_summary_screen.dart`

**Acceptance E:**

- [x] Same spacing/type scale as finance + chats on phone
- [x] No louder color fills; calm surfaces
- [x] Wide unchanged

---

### Phase F — Verify, plan 02 F3 notes, tests, iPhone re-smoke

| Step | Work |
| --- | --- |
| F1 | Automated: breakpoints + key widgets (shell gutter, dashboard pad, chat row density, composer fill off) |
| F2 | Update **only** [`02_Chat_and_Knows_UI_Upgrade.md`](02_Chat_and_Knows_UI_Upgrade.md) F3 / “Next” bullets: replace “filled composer / 16px gutters” language with remodel outcomes |
| F3 | iPhone device checklist (below) |
| F4 | Optional Android smoke (tokens shared; claim Android only if smoked) |

**Do not edit plan 02 until this phase.**

#### iPhone re-smoke checklist

| # | Check | ☐ |
| --- | --- | --- |
| 1 | Dashboard charts full phone width (no black letterbox sides) | ☐ |
| 2 | Accounts / Budgets same gutter system | ☐ |
| 3 | Chats: dense title+preview; search aligned; long titles ellipsize | ☐ |
| 4 | Composer: tall enough; no pill fill/shadow; send/attach/mic OK | ☐ |
| 5 | Knows / Goals / Profile spacing matches | ☐ |
| 6 | Bottom nav / Chats: history reachable in ≤1 tap; selected-label / chrome OK (tab count may change) | ☐ |
| 7 | Confirm strip inline, unclipped; home indicator OK | ☐ |
| 8 | Wide `/app/` still matches prior good layout (browser) | ☐ |

After F3 looks right → resume plan 02 C4 screenshots / A116; then plan 05 device smoke as before.

---

## Hard gates (restate)

- Phone-only visual changes behind `isNativeCompactChrome` (wide `/app/` must not regress)
- Tokens reusable for Android; iPhone smoke first
- **Allowed:** sixth bottom-nav tab; remove/relocate Chats sub-tab if history stays accessible
- **Still no:** barge-in; background voice (07); finance product IA rewrite; `apps/web` marketing edits
- File size: stop at 400; never grow past 500 — extract first
- Prefer root-cause layout tokens over one-off padding
- Nav / Chats chrome changes belong in a later shell pass (after A–B tokens prove out), not as Phase A scope creep

---

## Progress tracker

| Phase | Scope | Status |
| --- | --- | --- |
| **A** | Native layout tokens + shell gutter 0 | **DONE** (2026-07-12) — `ClarityNativeLayout` + shell gutter 0 on native compact; wide/web unchanged |
| **B** | Finance full-bleed (Dashboard → Accounts → Budgets) | **DONE** (2026-07-12) — pageGutter + single chart chrome; Accounts/Budgets tokens |
| **C** | Chats dense list + search align + title clamp | **DONE** (2026-07-12) — native dense title+1-line preview via `ClarityNativeLayout.active`; search H pad == list row; wide sidebar unchanged; Chats sub-tab kept |
| **D** | Composer + transcript (no fill) | **DONE** (2026-07-12) — kill pill fill; native minHeight 46 + fieldPadV 10; chrome H == pageGutter; transcript pad uses pageGutter; confirm stays inline |
| **E** | Knows / Goals / Overview / Profile | **DONE** (2026-07-12) — pageGutter + list/card tokens on native; wide pads preserved; memory/accountability extracts |
| **F** | Tests + plan 02 F3 notes + iPhone re-smoke | **TODO** (device smoke in progress) |
| **G** | Smoke follow-ups (screenshot refresh, Chats chrome, Profile) | **IN PROGRESS** (2026-07-13) |

### Phase G — Smoke follow-ups (from device feedback)

| Step | Work | Status |
| --- | --- | --- |
| G1 | Dashboard: do not reload on screenshot (`inactive→resumed`); only refresh after `paused`/`hidden` | DONE |
| G2 | Chats: Knows-like search/chips; `+` icon not big New chat; title-only rows; shorter titles (28, no `…`) | DONE |
| G3 | Profile: fewer duplicate section headers; Preferences group; calmer tiles | DONE |
| G4 | Re-smoke G1–G3 on iPhone; then finish Phase F docs | TODO |

---

## Implementation order reminder

1. **A** first (tokens + shell gutter) — unlocks measurable width without restyling everything.
2. **B** next — highest user pain (finance letterbox).
3. **C** then **D** — Chats density + composer (independent enough for parallel PRs after A, but sequential preferred).
4. **E** once gutters/list tokens proven.
5. **F** closes the loop with 02 F3 and device smoke.

**Start coding at Phase A when ready.** This file is the execution source of truth for the remodel; plan 02 remains cross-platform polish history + F smoke lists.
