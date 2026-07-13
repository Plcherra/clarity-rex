# 14 — Companion Proposal Honesty (Auto suggestions, modes, titles)

**Covers:** Make Auto suggestions trustworthy — **Off / Text / Card mean exactly what they say**, and stop garbage Goal / Open Thread titles from voice rambles.

**Canon:** `MASTER_PLAN.md` · `CLARITY_RULES.md` · `PROJECT_STRUCTURE.md`  
**Related:** [`01_Data_Integrity_and_Truth.md`](01_Data_Integrity_and_Truth.md) (confirm apply honesty) · [`13_Native_Phone_UI_Remodel.md`](13_Native_Phone_UI_Remodel.md) (UI only — does **not** fix this)

**Status:** Phases A–B implemented (Jul 2026). Text/Card contract and title refine still TODO. Triggered by Jul 2026 device smoke: Auto suggestions set to Off still produced confirm cards; Text vs Card behavior unclear; titles like “Plan to My Current Job Already Maintain Me On Th”.

**Out of this file:** Phone layout (13), barge-in / background voice (07), file→Knows import (08), finance IA.

---

## Mission

| Must | Must not |
| --- | --- |
| Modes match the product contract below | Silently save anything |
| User-visible setting matches what the API uses on each turn | Env override wipe user Off without clear ops intent |
| Confirm titles readable (not raw STT dump) | Grow orchestrator god-files past ~400–500 |
| Voice and chat same mode gates | Invent relationship / social facts |

**Product north star (CLARITY_RULES):** Calm companion. Durable writes only after user consent. Off is a trust control, not decoration.

---

## Product contract (locked — Jul 2026)

| Mode | Auto behavior | How consent / save works |
| --- | --- | --- |
| **Off** | **No ask. No card. No auto offer.** Rex just talks. | Nothing auto. (Explicit “please remember X” is user-initiated — still needs a confirm path; prefer respecting Off by staying text-only consent unless product later allows a one-shot card.) |
| **Text only** | Rex **asks in chat text** (“Want me to track X…?”). | User answers in text → **save + reply by text only**. **No confirm cards** (`write_proposals` not surfaced). |
| **Confirm card** | When eligible, the **confirm card appears** (editable strip). | User confirms/dismisses on the card → apply / reject. |

**Do not mix modes:**

- Off must not ask and must not show cards.
- Text must not show cards.
- Card must not pretend to be “ask only” — the card **is** the ask/confirm UI.

---

## User pain (must fix)

1. **Off ignored** — Auto suggestions = Off, but Rex still pushes confirm cards (and/or asks).
2. **Text mode dishonest** — UI / code still surfaces cards in “Text only”; should be chat ask + text save/reply only.
3. **Garbage titles** — Voice/long turns become truncated nonsense on Goal / Open Thread cards (Card mode).
4. **Copy mismatch** — Sheet hints still say Text mode “still shows a confirm card.”

---

## Current wiring (audit)

| Piece | Location | Notes |
| --- | --- | --- |
| Modes | `assistant_proposal_settings.py` | `off` / `text` / `card` |
| Profile load | `assistant_settings_repository.py` | Load fail → **Off** (fail-closed); empty profile still defaults to card via parse |
| Env override | `resolve_assistant_proposal_settings` | Env may force Off; **never** forces Card/Text over profile Off; leave unset in prod |
| Mobile save | `assistant_proposal_settings_sheet.dart` → `profiles.assistant_settings` | Persists + reloads Off |
| Threads | `open_thread_turn_service.py` | Gates `allows_kind(threads)`; missing settings → fail-closed Off |
| Goals | `conversational_plan_service.py` | Gates `allows_kind(goals)`; missing settings → fail-closed Off |
| Memory | `memory_turn_handle.py` | Gates `allows_kind(memory)` for all auto proposes |
| Title refine | `durable_write_proposal_refiner.py` | Mostly messy **memory** drafts; thread/goal titles still weak |
| Tests | `test_companion_proposal_matrix.py`, `test_text_mode_no_cards.py` | Off matrix green; Text-mode card expectations still wrong until Phase C |

**Gap vs contract:** Text mode historically still emits `write_proposals` in places (“cards are the truth path”). Phase C must make Text truly card-free while keeping apply honesty (text yes → backend apply → visible in Knows/Goals).

---

## Target behavior matrix

| Mode | Auto mid-chat | User says yes / confirm | Explicit “remember my mom’s birthday…” |
| --- | --- | --- | --- |
| **Off** | Silence — no ask, no card | N/A | User-initiated: text consent + text confirmation of save (no auto ask). Optional later: one-shot card only if we decide Off still allows explicit-save cards — default in this plan = **text-only even for explicit** so Off never shows cards. |
| **Text only** | Chat question only | Text yes → apply → text “Saved / tracking in Goals” (item visible). **No card.** | Same: text ask/confirm path only |
| **Confirm card** | Confirm card appears when eligible | Tap confirm/dismiss on card | Confirm card |

---

## Phased execution

### Phase A — Diagnose Off leak (no behavior change yet)

| Step | Work |
| --- | --- |
| A1 | Confirm profile row: after toggling Off, `profiles.assistant_settings.auto_proposals_mode == "off"` |
| A2 | On a chat turn, resolve effective mode (profile vs `REX_AUTO_PROPOSALS_MODE`) — check VPS env |
| A3 | Trace one failing turn: which service proposed (`open_thread` / `conversational_plan` / memory / polite-save) |
| A4 | Write findings into Progress tracker |

**Acceptance A:** Root cause named (env override / fail-open / not saved / ungated path).

---

### Phase B — Off means Off

| Step | Work |
| --- | --- |
| B1 | Persist + round-trip: mobile Off → API returns Off on next turn |
| B2 | Fail-**closed** on settings load error for autos: treat as Off, **not** default Card |
| B3 | Env override: never force Card over user Off (unset in prod or profile-wins policy) |
| B4 | Gate every auto propose path with `allows_kind` / `auto_proposals_enabled` |
| B5 | Tests: Off → no ask phrase, no `write_proposals`, no text offer |

**Acceptance B:**

- [x] Off + lifestyle / goal chat → **no ask, no card**
- [ ] Wide `/app/` same (manual)
- [x] Matrix tests green for Off

---

### Phase C — Enforce Text vs Card contract

| Step | Work |
| --- | --- |
| C1 | **Text only:** ask in chat; on yes, apply via text confirmation path; `surface_client_cards=false`; **never** emit client `write_proposals` |
| C2 | **Confirm card:** on eligible auto intent, show confirm card (current straight-card OK); no requirement to ask in text first |
| C3 | Update / replace tests that claim “text mode still includes write_proposals” (`test_text_mode_no_cards.py` → rename/rewrite to match contract) |
| C4 | Mobile: text mode must not render cards even if a stale proposal sneaks through (defense in depth — `chat_memory_change_parser` already notes text-only) |
| C5 | Rate-limit: one pending auto offer/propose per conversation until resolve |

**Acceptance C:**

- [ ] Text: ask in chat → yes → saved + text reply; **no card UI**
- [ ] Text: ask → no → nothing saved; no card
- [ ] Card: eligible turn → card appears; confirm → visible in Goals/Knows
- [ ] Off still silent (Phase B)

---

### Phase D — Readable Goal / Open Thread titles (Card mode)

| Step | Work |
| --- | --- |
| D1 | Extend refine helper to **open_thread** + **plan** when title/body look like STT dump |
| D2 | Cap card title length; body stays editable |
| D3 | Infer short human titles from intent |
| D4 | Tests: messy voice → clean title; clean short topic skips extra LLM |

**Acceptance D:** Long voice plan → short human card title; truth path unchanged.

---

### Phase E — Settings UX honesty + ops

| Step | Work |
| --- | --- |
| E1 | Rewrite Off / Text / Card hints to match the locked contract (remove “Text still shows a confirm card”) |
| E2 | Snackbar if needed: “Saved — applies on next message” |
| E3 | Ops: `REX_AUTO_PROPOSALS_*` empty in prod unless intentional kill-switch |
| E4 | Optional: show effective mode when env overrides |

**Acceptance E:** Three modes explainable in one sentence each; copy matches runtime.

---

### Phase F — Verify + smoke

| # | Check | ☐ |
| --- | --- | --- |
| 1 | Off → no ask, no card | ☐ |
| 2 | Text → chat ask only; yes → text save/reply; no card | ☐ |
| 3 | Card → card appears; confirm works | ☐ |
| 4 | Card titles clean after long voice | ☐ |
| 5 | Voice parity with chat for all three modes | ☐ |
| 6 | Wide `/app/` same | ☐ |
| 7 | pytest + flutter tests for matrix | ☐ |

---

## Hard gates

- Truth Rule: never claim saved until apply succeeded and item is visible
- Text mode: consent + success messaging stay honest without cards
- Voice and chat same gates
- File size: extract before growing orchestrator / turn services
- Off = zero auto ask and zero auto cards

---

## Progress tracker

| Phase | Scope | Status |
| --- | --- | --- |
| **A** | Diagnose Off leak | **DONE** (Jul 2026) |
| **B** | Off means Off | **DONE** (Jul 2026) |
| **C** | Text = text-only; Card = card | **TODO** |
| **D** | Goal / thread title refine | **TODO** |
| **E** | Settings copy + ops | **TODO** |
| **F** | Tests + smoke | **TODO** (partial Off coverage in B) |

### Phase A findings (root cause)

Device smoke: Auto suggestions = Off still produced confirm cards / asks.

| Check | Result |
| --- | --- |
| A1 Profile save | Mobile `AssistantProposalSettings.toJson()` writes `auto_proposals_mode: "off"` to `profiles.assistant_settings` — persist path OK |
| A2 Env override | `REX_AUTO_PROPOSALS_MODE` **replaced** profile mode entirely — env `card` wiped user Off (primary prod leak if set on VPS) |
| A3 Propose paths | Threads/goals already gated via `allows_kind`; **memory simple-fact propose was not fully gated** when Off; missing `proposal_settings` fell back to **Card**; load errors **fail-opened to Card** via `resolve({})` |
| A4 Root cause | **Compound:** (1) env Card overrides profile Off, (2) settings load / missing settings fail-open to Card, (3) memory auto-propose skipped the Off gate for simple intents |

### Phase B fix summary

- Fail-closed on profile load error → Off (`fail_closed_proposal_settings`)
- Env never forces Card/Text over profile Off; env Off remains kill-switch; leave unset in prod (`.env.example`)
- Gate memory auto proposes when `!allows_kind(memory)`; service fallbacks use fail-closed Off instead of Card
- Off skips pending-write reminder ask/cards
- Tests: Off habit/sleep/goal-ish → no offer phrase, no `write_proposals`; profile Off wins over env Card

**Acceptance B:**

- [x] Off + lifestyle / goal chat → **no ask, no card** (pytest matrix)
- [ ] Wide `/app/` same (manual smoke)
- [x] Matrix tests green for Off

---

## Implementation order

1. **A → B** — Off must be trustworthy first.  
2. **C** — lock Text vs Card.  
3. **D** — card title quality.  
4. **E → F** — copy + smoke.

**Start coding at Phase A/B when ready.**
