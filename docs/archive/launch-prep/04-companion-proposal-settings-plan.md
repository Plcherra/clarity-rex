# Companion proposal settings — implementation plan

**Status:** Shipped (Phases A–C complete)  
**Session context:** Raw Grok chat testing surfaced auto-save/open-thread cards interrupting companion flow.

---

## 1. Product spec (correct)

User chooses **one confirmation mode** for *automatic* proposals (explicit “save this” always allowed):

| Mode | Behavior |
|------|----------|
| **off** | No auto proposals. User creates in Knows/Goals manually or asks Rex explicitly. |
| **text** | Auto-detect → short chat offer only (“Want me to track this…?”). No surprise card until user says yes. |
| **card** | Auto-detect → confirm card in chat (current production-style). |

Plus **per-type toggles** (only apply when mode ≠ off):

- **Open threads** — habits / recurring accountability (“change sleep schedule”, “wake up every day at 6”)
- **Goals** — one-time outcomes (“buy X”, “start gym”, “plan trip”)
- **Memory** — contextual auto-memory (not explicit “remember this” commands)

### Semantic rules (threads vs goals)

| Type | Examples |
|------|----------|
| **Thread** | “I want to change my sleep schedule”, “wake up at 6 every day”, night routine |
| **Goal** | Buy something, join gym, visit place, plan event, launch project |
| **Neither (companion chat only)** | “Can’t sleep tonight”, “gotta wake at 6:30 **tomorrow**”, venting, one-off work |

### Companion invariant (all modes)

After user **confirms or dismisses** a proposal (text yes/no or card Confirm/Dismiss), Rex **must continue the conversation** on the original topic — never dead-end on “Okay, I won’t save…”.

---

## 2. UI placement (not Profile)

Settings live in the **Assistant area**, not Profile.

**Recommended (user):** top assistant tab bar — gear / tune icon on the right of `Chat | Knows | Goals | Chats` in `assistant_screen.dart` → bottom sheet or small panel.

**Alternative:** icon near mic on chat input bar (secondary).

### Settings sheet contents

1. **Auto suggestions:** Off / Text only / Confirm card (segmented control)
2. When not Off:
   - Toggle: Open threads
   - Toggle: Goals
   - Toggle: Memory

Persist to `profiles.assistant_settings` (JSONB). Mobile reads on launch; backend loads per chat turn.

**Do not** expose `REX_AUTO_PROPOSALS_*` as the primary UX — env overrides optional for local dev only.

---

## 3. Voice flags (informational — not part of this plan)

Two mobile flags, one production path:

```text
REX_STREAMING_VOICE_ENABLED=true  (default)
  → WebSocket /voice/stream (live STT → ChatService → streaming TTS)

If streaming connect fails AND REX_CLOUD_VOICE_ENABLED=true:
  → fallback: record utterance → POST /voice/turn (batch STT → ChatService → MP3 TTS)

REX_STREAMING_VOICE_ENABLED=false:
  → skip WebSocket; use /voice/turn directly every utterance (legacy/simpler path)

Both false:
  → voice disabled (chat-only)
```

`/voice/turn` is **not** a separate brain — same `ChatService` / orchestrator as chat and streaming. It is a **transport fallback** (record whole clip, upload, wait for full MP3). For local raw **chat** testing, both flags `false` is correct. Voice testing needs streaming (and cloud fallback optional).

---

## 4. Backend design

### 4.1 Settings model

```json
{
  "auto_proposals_mode": "off" | "text" | "card",
  "auto_proposals_threads": true,
  "auto_proposals_goals": true,
  "auto_proposals_memory": true
}
```

Module: `assistant_proposal_settings.py` — extend to **three modes** (current partial work only has off|text).

Load in `ChatTurnContextService.prepare()` from profile via `AssistantSettingsRepository`.

### 4.2 Routing by mode

| Service | off | text | card |
|---------|-----|------|------|
| `open_thread_turn_service` | skip auto | text offer → card only after yes | text offer OR direct card per eligibility |
| `conversational_plan_service` | skip auto | text offer | `propose_discipline_decision` card |
| `memory_turn_handle` (contextual) | skip auto | text offer | card propose |

Restore **card path** when `mode == card` (partial work removed auto-cards entirely — wrong).

### 4.3 Eligibility (keep)

`open_thread_eligibility.py` — sleep vent, one-off “wake tomorrow” vs habit signals.

### 4.4 Continuation (keep)

`write_resolution_continuation.py` — after confirm/dismiss, one Grok turn on original topic.

---

## 5. Mobile design

| File | Change |
|------|--------|
| `assistant_screen.dart` | Gear icon in `_AssistantTopSurface` → settings sheet |
| `assistant_proposal_settings.dart` | Add `card` mode |
| `assistant_proposal_settings_controller.dart` | Load/save via ProfileService or dedicated Supabase patch |
| Remove from `profile_screen.dart` | Companion settings section (wrong placement) |

SharedPreferences cache optional for instant UI before profile hydrate.

---

## 6. Migration

`20260707000100_add_profiles_assistant_settings.sql` — already drafted; run `supabase db push`.

---

## 7. Phases

### Phase A — Fix spec + stop wrong UX (1 session)

- [x] Revert Profile tab companion settings UI
- [x] Fix backend enum: `off | text | card`
- [x] Restore card auto-propose when `mode=card`
- [x] Default for new users: **`text`** (companion-first)

### Phase B — Assistant settings UI (1 session)

- [x] Gear on assistant top bar
- [x] Sheet with mode + type toggles
- [x] Wire to `profiles.assistant_settings`

### Phase C — Polish (1 session)

- [x] Continuation after all resolution paths (verify voice + chat)
- [x] Tests: settings matrix × sleep vent × habit thread
- [x] Remove dev env vars from docs except “local override” footnote

---

## 8. Raw Grok testing (until Phase A/B ship)

For uninterrupted companion feel:

1. `REX_BRAIN_PROMPT_MODE=raw` in `services/rex-api/.env`
2. Assistant tab → gear icon → **Companion saves** (Off / Text only / Confirm card)
3. Flutter web + local backend — chat only; voice needs streaming enabled

Dev-only override: `REX_AUTO_PROPOSALS_MODE=off` in rex-api `.env` if profile column not migrated yet.

---

## 9. Shipped modules

- `assistant_proposal_settings.py` — off | text | card + per-type toggles
- `open_thread_turn_service.py` — mode-gated text/card offers
- `conversational_plan_service.py` — text offer or card by mode
- `write_resolution_continuation.py` — companion continuation after confirm/dismiss
- `open_thread_eligibility.py` — sleep vent vs habit thread signals
- `assistant_proposal_settings_sheet.dart` — gear icon settings in Assistant tab
