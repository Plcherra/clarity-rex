# 02 — Chat and Knows UI Upgrade (Lightweight Polish)

**Covers:** Make Assistant chat and Knows feel lighter and more practical (Grok-like density), without a full redesign or new design system. Canon separation: Goals stay on the Goals tab only.

**Primary paths:** `chat_message_bubble.dart`, `chat_transcript.dart`, `clarity_action_cards_strip.dart`, `saved_memory_group_list.dart`, `saved_memory_tile_shell.dart` / entity tiles, `RexUiTokens`, Knows edit sheets

**Canon:** `CLARITY_RULES.md` — Saved Memory in Knows; Goals in Goals; keep them separate.

---

## Phase 1 — Canon: Goals out of Knows

### Issue: Goals group rendered inside Knows (A70)

- **Severity:** High (product clarity)
- **Why it matters:** Users see the same goals in Knows and Goals; violates “clearly separate Saved Memory and Goals.”
- **Estimated effort:** Small
- **Brief fix suggestion:** Remove `MemoryGroup.goals` / plan tiles from `SavedMemoryGroupList` and Knows filters that only exist to surface plans. Keep create/edit of plans on Goals tab (and chat confirm → Goals refresh). Update Knows empty-state copy if it mentions goals.

---

## Phase 2 — Chat bubbles: lighter density

### Issue: Solid teal user bubbles feel heavy (A71)

- **Severity:** Medium
- **Why it matters:** Dense filled bubbles dominate the transcript; Grok-like UIs use muted text + slight tint.
- **Estimated effort:** Small
- **Brief fix suggestion:** In `chat_message_bubble.dart`, replace solid `RexUiTokens.userBubble` fill with a soft tint (low-alpha teal or elevated surface) and keep readable contrast for dark mode. Preserve streaming / expandable assistant behavior.

### Issue: Bubble and transcript spacing too large (A72)

- **Severity:** Medium
- **Why it matters:** Large padding + `bodyLarge` + generous list gaps make short turns feel like cards.
- **Estimated effort:** Small
- **Brief fix suggestion:** Tighten horizontal/vertical padding in the bubble; reduce inter-message spacing in `chat_transcript.dart` (and voice interim spacing if needed). Prefer token tweaks over one-off magic numbers where possible.

---

## Phase 3 — Knows: practical rows, details on tap

### Issue: Knows tiles show too much chrome (A73)

- **Severity:** Medium
- **Why it matters:** Title + long subtitle + type · importance · date + icons makes scanning hard.
- **Estimated effort:** Medium
- **Brief fix suggestion:** Default row = **title + one meta line** (e.g. type or short subtitle). Move importance and updated/created dates into the existing edit sheet only. Keep overflow menu / archive actions reachable.

### Issue: Knows list still feels card-heavy after density pass (A74)

- **Severity:** Low–Medium
- **Why it matters:** Large radius + thick surfaces read as dashboard cards, not a memory list.
- **Estimated effort:** Small
- **Brief fix suggestion:** Slightly reduce tile padding/radius in the shared tile shell; avoid nested “card in card” chrome. Do not invent a second design system.

---

## Phase 4 — Confirm strip slim-down

### Issue: Confirm action strip padding is heavy (A75)

- **Severity:** Low–Medium
- **Why it matters:** Pending save cards compete with the transcript; voice dialogs inherit the same weight.
- **Estimated effort:** Small
- **Brief fix suggestion:** Reduce padding in `clarity_action_cards_strip.dart`; keep confirm/reject affordances obvious and truth-honest (no visual “success” without applied).

---

## Phase 5 — Verify

### Issue: Visual + canon smoke after polish (A76)

- **Severity:** Medium (gate)
- **Why it matters:** Density changes can hurt contrast or hide actions.
- **Estimated effort:** Small (manual + focused Flutter tests)
- **Brief fix suggestion:** Smoke: chat send/stream; voice interim; confirm card; Knows list without Goals; open edit sheet shows importance/date; Goals tab still lists plans. Run existing bubble/Knows widget tests; add/adjust golden or widget expectations if copy/layout assertions break.

---

## Out of scope (do not pull into this file)

- Full rebrand, new fonts, glassmorphism, or Material 3 rewrite
- Spanish FTUE / marketing copy (file 08)
- Voice hang / listening stuck (file 07)
- Backend memory intent / location clarifier (code fix; not UI)
