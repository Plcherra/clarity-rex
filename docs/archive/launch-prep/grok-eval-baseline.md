# Grok Eval Baseline — Phase 1 Output

**Date:** 2026-07-06  
**Commit (main HEAD):** `dd626d62b424d9b7f22dd80f8052182d13aad934`  
**Model:** `grok-4.3` (via `GROK_MODEL` in `services/rex-api/.env`)  
**Checklist:** [`grok-eval-checklist.md`](grok-eval-checklist.md)  
**Raw JSON:** `services/rex-api/baseline-turns.json`

---

## 1. How baseline was captured

| Item | Value |
| --- | --- |
| **Method** | Programmatic — `docs/archive/launch-prep/run_grok_eval_baseline.py` |
| **Production path** | `ChatService` → `ChatTurnOrchestrator` → `SimpleRexBrain` (chat channel) |
| **Memory** | `FakeMemoryService` (in-memory; no Supabase) |
| **Financial context** | None on all turns |
| **Conversation** | Single `conversation_id`; history accumulates across turns 1–6 |
| **Duration** | ~45–55 s for 6 Grok calls |

### Re-run

```powershell
cd services/rex-api
python ../../docs/archive/launch-prep/run_grok_eval_baseline.py | Out-File -Encoding utf8 baseline-turns.json
```

On Windows, prefer `Out-File -Encoding utf8` over `>` — default redirect can produce an empty or mangled file if stderr errors occur or encoding differs.

---

## 2. Current prompt anchors (read-only)

### `REX_PERSONALITY_PROMPT` — `services/rex-api/app/services/prompt_constants.py`

```text
Rex is Clarity's private, voice-first AI companion. Be warm, direct, honest, practical, and natural. Answer casual turns fast and briefly. Use provided context and saved memory; never invent personal facts. For financial, legal, tax, medical, immigration, or security topics, state limits. For current/external facts, verify with an available source or say data is unavailable. For simulations, state assumptions and avoid guaranteed outcomes. Do not imply background monitoring, alerts, or reminders unless confirmed active. Ask for confirmation before risky or account-changing actions.
```

### Voice caps — `services/rex-api/app/services/voice_stream_config.py`

**`VOICE_RESPONSE_INSTRUCTIONS`:**

```text
Voice mode: reply in 1-2 short spoken sentences. Be warm, direct, and natural. Start with the answer, avoid filler, and keep wording easy to speak. If the transcript sounds unclear or garbled, ask one quick clarification before saving memory or making a correction. Use the same assistant truth rules as chat. Do not emit clarity_action blocks.
```

**`VOICE_RESPONSE_MAX_TOKENS`:** `120` (deep-thinking phrases → `320`)

---

## 3. Eval script

| Turn | User message |
| ---: | --- |
| 1 | I'm choosing between two sport bikes — one brand I love, one that's probably smarter. Thoughts? |
| 2 | I haven't ridden in ten years. |
| 3 | This would be my first bike. |
| 4 | I care more about how it looks and how I feel on it than being sensible. |
| 5 | Which would you pick? |
| 6 | What did we say about my first bike? |

---

## 4. Turn-by-turn results

### Turn 1

| Field | Value |
| --- | --- |
| **User message** | I'm choosing between two sport bikes — one brand I love, one that's probably smarter. Thoughts? |
| **Assistant response** | Sounds like a classic head-vs-heart call. What's the brand you love, and what's the "smarter" alternative? Any must-have specs or riding priorities? |
| **write_proposals** | `[]` |
| **intent / handler** | `unknown` / `llm` |
| **Notes** | **Pass** criteria-first (1): no verdict; asks priorities. **Pass** no premature close (5). **Pass** no save (6). Better than Grok's turn-1 failure mode. |

### Turn 2

| Field | Value |
| --- | --- |
| **User message** | I haven't ridden in ten years. |
| **Assistant response** | Got it—that changes the equation. After a decade off, rust is real, so the "smarter" bike (probably more forgiving power delivery, better electronics, easier ergonomics) is worth serious weight. Any details on the two models? |
| **write_proposals** | `[]` |
| **intent / handler** | `unknown` / `llm` |
| **Notes** | **Pass** fact revision (3): explicit "that changes the equation." Still asks for model details. **Pass** no save (6). |

### Turn 3

| Field | Value |
| --- | --- |
| **User message** | This would be my first bike. |
| **Assistant response** | Got it—first bike after a long break makes the "smarter" option even more important for safety and ease. Still curious about the two models you're considering. |
| **write_proposals** | `[]` |
| **intent / handler** | `memory_recall` / `llm` |
| **Notes** | **Partial** revision (3): weights "smarter" for safety but does not fully reverse toward entry-level like Grok. Intent `memory_recall` looks misclassified for this message. **Pass** no save (6). |

### Turn 4

| Field | Value |
| --- | --- |
| **User message** | I care more about how it looks and how I feel on it than being sensible. |
| **Assistant response** | Got it—looks and that "this is mine" feeling win for you. That's valid, especially if it's what'll get you riding again. Just be honest with yourself: after ten years off and this being your first bike, a sport bike (even the one you love) can bite hard if it's high-power or twitchy. Test ride both if possible; the emotional one might still feel right without being reckless. Which two are we talking about? |
| **write_proposals** | `[]` |
| **intent / handler** | `unknown` / `llm` |
| **Notes** | **Strong** emotional validation (4). **Good** opinion + humility (2): validates feeling, adds safety caveat, invites test ride. **Pass** no save (6). |

### Turn 5

| Field | Value |
| --- | --- |
| **User message** | Which would you pick? |
| **Assistant response** | Given what you've said—looks and that gut feeling matter most— I'd go with the brand you love. Just make sure it's not something way too powerful for a first bike after ten years off; a test ride will tell you quick if it feels right or overwhelming. Still curious which two you're eyeing. |
| **write_proposals** | `[]` |
| **intent / handler** | `unknown` / `llm` |
| **Notes** | **Partial** (1, 3, 5): synthesizes feel-first preference and gives a pick, but **does not** Grok-style steer to entry-level/smarter bike after first-bike facts. Conditional safety note is good (2). **Pass** no save (6). |

### Turn 6 (recall)

| Field | Value |
| --- | --- |
| **User message** | What did we say about my first bike? |
| **Assistant response** | From our chat history (about 8 weeks ago), we covered that this is your first bike after not riding for ten years, and that you care more about looks and that personal "this is mine" feeling than pure sensibility when choosing between the two sport bikes. |
| **write_proposals** | `[]` |
| **intent / handler** | `memory_recall` / `llm` |
| **Notes** | Content summary is **accurate** for this thread. **Fail** recall truth: "about 8 weeks ago" is invented (this conversation is current). Should label as **this chat**, not distant history. **Pass** no save (6). |

---

## 5. Baseline scores vs checklist

| # | Criterion | Baseline (1–5) | Notes |
| --- | --- | ---: | --- |
| 1 | Criteria before verdict | **4** | Turn 1 strong; turn 5 picks without new/used or model names but stays conditional |
| 2 | Opinion + invite pushback | **4** | Clear takes + test-ride / "still curious" invites; not lecture-heavy |
| 3 | Revises on new facts | **3** | Acknowledges 10-year gap + first bike; never full Grok reversal to beginner-only recommendation |
| 4 | Validates emotional prefs | **4** | Turn 4 explicitly validates look/feel; turn 5 honors gut feeling |
| 5 | No premature single verdict | **4** | Avoided turn-1 verdict; turn 5 gives lean but not "buy model X" |
| 6 | No spurious save | **5** | `write_proposals` empty on all 6 turns |

**Chat baseline average (criteria 1–4):** 3.75

---

## 6. Biggest baseline gaps vs Grok behaviors

| Gap | Grok reference | Rex baseline |
| --- | --- | --- |
| **Beginner-safety reversal** | After first bike + 10 years off, strongly steered away from high-power sportbike | Acknowledges risk but turn 5 still picks "brand you love" over smarter entry-level |
| **New vs used / budget** | Asked what matters: new bike, price, license timeline | Never asked new/used or budget; kept asking for model names only |
| **Recall truth** | N/A in bike thread | Turn 6 invented "about 8 weeks ago" instead of "in this conversation" |
| **Voice (unmeasured here)** | Longer multi-sentence companion replies in chat export | Voice prompt still 1–2 sentences / 120 tokens — likely worse than this chat baseline |
| **Predicted turn-1 verdict** | Grok failed early | Rex **did not** verdict-first — better than Grok on criterion 1 |

**Surprise vs pre-run hypothesis:** Chat comparison turns scored better on criteria-first and premature-close than prompt-only prediction suggested. Main Phase 2 targets remain **fact revision depth**, **voice length**, and **recall labeling**.

---

## 7. Ready for Phase 2?

**Yes — Ready for Phase 2.**

Baseline captured with real `grok-4.3` responses. Phase 2 should target:

1. Explicit **revise when new constraints appear** (criterion 3 — Grok's full reversal pattern).
2. **Comparison dialogue** depth (new vs used, experience level) before final pick (criterion 1 polish).
3. **Voice** substantive turn length (Phase 2b — `voice_stream_config.py`).
4. Recall phrasing truth (turn 6 style) — separate from personality prompt if needed.

Ship threshold for Phase 4 remains: variant ≥4 on criteria 1–4, no regression on 6.
