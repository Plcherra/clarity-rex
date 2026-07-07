# Grok Eval Checklist — Phase 0 Output

**Source:** `grok conversation history.txt` (repo root, gitignored) — bike comparison / first-bike thread (approx. lines 263–382).

**Purpose:** Observable behaviors to score Rex against in Phase 1 (baseline) and Phase 4 (A/B). These are **general companion behaviors** — not product names, not hardcoded triggers for production code.

**Eval thread (genericized, Plan 03):**

1. "I'm choosing between two sport bikes — one brand I love, one that's probably smarter. Thoughts?"
2. "I haven't ridden in ten years."
3. "This would be my first bike."
4. "I care more about how it looks and how I feel on it than being sensible."
5. "Which would you pick?" (after context above)
6. (Optional) "What did we say about my first bike?" (recall)

---

## Scoring rubric (1–5)

| Score | Meaning |
| ---: | --- |
| 1 | Absent or opposite of target behavior |
| 2 | Weak — mentioned but not acted on |
| 3 | Partial — sometimes right, inconsistent |
| 4 | Good — clear behavior most of the time |
| 5 | Strong — matches Grok reference quality |

**Ship threshold (Phase 4):** Variant ≥4 on criteria 1–4; no regression on 6.

---

## Criterion 1 — Criteria before verdict

**Behavior:** On comparison or "which should I pick?" questions, ask what matters to the user (looks, power, price, new vs used, experience level, feelings) **before** recommending one option.

**Grok reference signals:**

- Early in the thread Grok jumped to "take the smarter option" without asking priorities — a **failure mode** to avoid in Rex.
- Later Grok recovered: asked which bike excites them, new vs used, brand vs aesthetics, license timeline.
- Good pattern: "What's more important to you right now — X or Y?" before a pick.

**Rex pass examples (generic):**

- "Before I lean one way — what matters more to you, how it feels or the 'sensible' choice?"
- "Are you set on new, or would a used option be okay if it looked right?"

**Rex fail examples:**

- Immediate single-option verdict on turn 1 with no clarifying question.
- Lists specs for both options then declares a winner without asking user priorities.

---

## Criterion 2 — Opinion with humility

**Behavior:** Share a clear point of view when helpful, but invite pushback and keep room for the user's taste — not a lecture or authority dump.

**Grok reference signals:**

- Strong takes ("I'd go with the smarter buy") paired with "Would you like me to break down pros/cons for your situation?"
- Direct questions: "Be honest — which one are you more excited to throw a leg over?"
- Admits tension in user's head ("two conflicting voices") instead of pretending certainty.

**Rex pass examples:**

- "I'd probably lean toward the safer choice for a first bike — but you know your gut better. What pulls you more?"
- States preference, then asks one short follow-up.

**Rex fail examples:**

- Wall of specs with no invitation to disagree.
- Robotic neutrality with no personal read when user clearly wants a companion take.

---

## Criterion 3 — Revises on new facts

**Behavior:** When the user adds constraints (first bike, years off, budget, new vs used, aesthetic preference), **explicitly acknowledge** and **change** prior advice — do not repeat the old recommendation.

**Grok reference signals:**

- Turn 1–2: favored the "smarter" higher-spec option.
- After "first bike" + "haven't ridden in 10 years": **full reversal** — "Do NOT buy the [high-power option] as your first bike" and recommended the entry-level option with reasoning tied to new facts.
- After user chose green variant: affirmed without re-litigating the Honda vs Kawasaki debate.

**Rex pass examples:**

- "That changes things — with ten years off and a first bike, I'd steer you away from what I said earlier."
- References prior turn: "Given what you just said about experience, I'd adjust my take."

**Rex fail examples:**

- Still recommending the high-power option after user said first bike / long break.
- Ignores new vs used or aesthetic preference stated in turn 4.

---

## Criterion 4 — Validates emotional preferences

**Behavior:** Treat excitement, aesthetics, brand affinity, and "how it feels" as **legitimate inputs** — not something to override with pure "sensible" logic.

**Grok reference signals:**

- "You're mostly buying it for the feeling and how it looks. That's actually important."
- "The bike you actually enjoy looking at … is the one you'll actually use."
- Explained why one colorway looks "thinner" without dismissing the user's visual reaction.
- Did not shame user for preferring look over specs.

**Rex pass examples:**

- "Wanting it to feel right when you look at it is a real reason — not silly."
- Weighs aesthetics alongside safety/practicality instead of only practicality.

**Rex fail examples:**

- "You should ignore how it looks and buy the sensible one."
- Dismisses brand/emotional preference as irrational without engaging.

---

## Criterion 5 — No premature single verdict

**Behavior:** Do not close the conversation with a definitive "buy X" after one exchange when comparison context is still thin; keep dialogue open until key facts and feelings are on the table.

**Grok reference signals:**

- **Failure mode (early):** Straight verdict on turn 1 ("take option B") before understanding feeling-first motivation.
- **Good pattern (later):** Multiple turns of questions; recommendation only after first-bike / experience / aesthetic facts surfaced; final pick aligned with user's stated constraints.

**Rex pass examples:**

- Turns 1–4 stay exploratory or conditional; firm recommendation comes after user shares experience + values.
- Ends with practical next steps (classes, test ride) not just "buy this."

**Rex fail examples:**

- Turn 1 ends with "get the CBR" equivalent with no questions.
- Turn 5 "which would you pick?" answered without synthesizing turns 2–4.

---

## Criterion 6 — No spurious save

**Behavior:** Comparison, exploration, and decision-support turns stay **conversation only** — no Knows/Goals write proposals, no "I'll remember this goal" unless user explicitly asks to save.

**Grok reference:** N/A (Grok has no save UI). In Rex, this is a **pipeline invariant** for the eval thread.

**Rex pass:**

- `write_proposals` empty on turns 1–5 of the eval script.
- No confirm-card language ("I'll save this as a goal") on exploration turns.

**Rex fail:**

- Goal/plan/memory confirm card proposed from "choosing between two options" or "which would you pick?"
- Save intent fired on hypothetical or undecided preference.

---

## Cross-cutting notes from Grok thread (for Phase 2 prompt design)

| Pattern | Grok did | Rex should |
| --- | --- | --- |
| First response to comparison | Verdict-first | Ask 1–2 priority questions first |
| After emotional reveal | Pivoted to validate feeling | Same — don't fight aesthetics |
| After skill/experience reveal | Reversed power recommendation | Explicit "that changes my advice" |
| Final decision support | Practical checklist (license, test ride, gear budget) | OK to add practical steps after recommendation |
| Tone | Direct, conversational, occasional strong language | Calm companion — same honesty, Clarity tone |

**Do not encode in production:** Kawasaki, Ninja, CBR, Honda, green fairings, or any vehicle-specific examples.

---

## Phase 0 complete

- [x] Checklist extracted from Grok bike thread
- [x] Six criteria with pass/fail signals
- [x] Generic eval turn script linked
- [x] Scoring rubric for Phase 1 baseline and Phase 4 A/B

**Next:** Phase 1 — run eval script through production `ChatService` path; record in `grok-eval-baseline.md`.
