# Grok Conversation Eval — Execution Plan

**Purpose:** A/B companion tone and reasoning against the user's Grok reference (`grok conversation history.txt`, Kawasaki vs CBR / first-bike thread) using **general** prompt changes — no hardcoded bike triggers.

**Estimated time:** 5–6 h (Phases 0–5); pairs with Plan 01 in one ~8 h session  
**When:** Session 1, immediately after Plan 01 — **not** parallel with Plan 02  
**Orchestration:** Read `00-session-orchestration.md` for file ownership.

---

## Success criteria

- [ ] Rex asks about user criteria/feelings before verdict on comparison questions
- [ ] Rex revises advice when new facts appear (first bike, years off riding)
- [ ] Rex does **not** propose goal saves on comparison/exploration turns
- [ ] Voice replies feel companion-like within token limits (warm, not lecture)
- [ ] No bike/Kawasaki/Ninja hardcoded strings in prompts or guards

---

## Reference material

| Asset | Location |
| --- | --- |
| Grok transcript | `grok conversation history.txt` (repo root or user-provided path) |
| Current personality | `services/rex-api/app/services/prompt_constants.py` → `REX_PERSONALITY_PROMPT` |
| Voice LLM caps | `services/rex-api/app/services/voice_stream_config.py` → `VOICE_RESPONSE_INSTRUCTIONS`, `VOICE_RESPONSE_MAX_TOKENS` |
| Prompt assembly | `services/rex-api/app/services/prompt_service.py` |
| Save mis-fire guards | `services/rex-api/app/services/save_intent_guards.py` |

---

## Phase 0 — Extract eval checklist from Grok thread (2 h, read-only)

From the bike section, list **behaviors** (not product names):

1. **Criteria first** — asks what matters (looks, power, price, new vs used) before picking
2. **Opinion with humility** — shares view, invites pushback
3. **Fact revision** — updates when user says first bike / 10 years off / budget change
4. **Emotional validation** — treats excitement and aesthetics as valid inputs
5. **No premature close** — doesn't end with single-model verdict without dialogue
6. **No spurious save** — exploration stays conversation, not Knows/Goals

Write checklist to `docs/archive/launch-prep/grok-eval-checklist.md` (archive OK — not canon).

---

## Phase 1 — Baseline capture (1 h)

Run **current** production prompts against 5–8 scripted user turns (text chat is enough for tone A/B; voice optional):

Example turn script (genericized):

1. "I'm choosing between two sport bikes — one brand I love, one that's probably smarter. Thoughts?"
2. "I haven't ridden in ten years."
3. "This would be my first bike."
4. "I care more about how it looks and how I feel on it than being sensible."
5. "Which would you pick?" (after context above)
6. "What did we say about my first bike?" (recall — optional)

Record for each: response text, save proposals (should be none), handler/intent if logged.

Store baseline in `docs/archive/launch-prep/grok-eval-baseline.md`.

---

## Phase 2 — Draft prompt changes (2–3 h)

### 2a — `REX_PERSONALITY_PROMPT` (chat + voice brain)

Add **general** companion principles (wording TBD in implementation PR):

- On comparisons: ask 1–2 clarifying questions about priorities before recommending
- When user shares new constraints: acknowledge and adjust prior advice explicitly
- Validate stated preferences; don't override with "sensible" only
- Keep casual turns brief; **comparison/emotional turns may use more sentences**

Remove or soften: "Answer casual turns fast and briefly" as global rule — scope brevity to greetings/small talk only.

### 2b — Voice instructions (`voice_stream_config.py`)

Current pressure: "1-2 short spoken sentences" + 120 max tokens → robotic verdicts.

Proposed experiment (A/B):

- **Variant A:** 2–4 sentences for substantive turns; keep 120 tokens initially
- **Variant B:** 2–4 sentences + raise to 180–220 tokens for substantive (not casual) turns

Implement variant behind env flag if possible: `REX_VOICE_SUBSTANTIVE_MAX_TOKENS` (default conservative).

### 2c — Do NOT change

- Save intent guards (unless eval shows gaps — separate small PR)
- Hardcoded bike/motorcycle triggers
- Financial context gates

---

## Phase 3 — Automated regression guards (1 h)

**Do not edit `test_prompt_service.py`** while Plan 02 Phase 4 split is pending — use a dedicated file:

| Test file | Assert |
| --- | --- |
| `tests/test_personality_prompt_regression.py` **(new)** | New personality strings present; no vehicle-specific examples |
| `test_save_intent_guards.py` | Re-run existing; extend only if eval finds save gap |
| Optional | Snapshot test for prompt section labels unchanged |

---

## Phase 4 — A/B manual eval (2 h)

Score **baseline vs variant** on checklist (Phase 0), 1–5 each:

| # | Criterion | Baseline | Variant |
| --- | --- | ---: | ---: |
| 1 | Criteria before verdict | | |
| 2 | Opinion + invite pushback | | |
| 3 | Revises on new facts | | |
| 4 | Validates emotional prefs | | |
| 5 | No premature single verdict | | |
| 6 | No save proposal | | |

**Ship threshold:** Variant ≥4 on criteria 1–4; no regression on 6.

Voice spot-check: read aloud 2 turns — does Charon TTS sound natural with longer text?

---

## Phase 5 — Ship decision (30 min)

- If variant wins: merge prompt + voice instruction PR
- If tie: prefer smaller token increase + criteria-first prompt only
- If variant worse on saves/latency: revert token change, keep prompt only

Document decision in PR description; no new canon docs.

---

## Phase 6 — Post-launch (optional)

- Expand eval script to pytest with mocked Grok responses
- Add recall turn to eval when chat search quality work lands
- Option B from prior discussion: profile flag for richer chat recall (separate feature)

---

## Agent handoff prompt (copy-paste)

```
Execute docs/archive/launch-prep/03-grok-eval-plan.md Phase N only.
Use grok conversation history.txt for checklist behaviors only — no hardcoded bike triggers in production code.
Compare against prompt_constants.py and voice_stream_config.py.
Run test_save_intent_guards and test_prompt_service after prompt edits.
Separate PR from Plan 01 hygiene and Plan 02 test splits.
```

---

## Suggested chat/agent sequence

See **`00-session-orchestration.md`** for the full schedule. Summary:

| Session | Plans | ~Hours |
| --- | --- | ---: |
| **1** | 01 complete + 03 complete | ~8 |
| **2** | 02 Phase 1 + Phase 2 | ~8 |
| **3** (optional) | 02 Phase 3–4 | ~8 |

Session 1 is the default pre-launch sprint (behavior > test file size).
