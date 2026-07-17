# MASTER_PLAN.md

**Canon:** product vision only. Behavioral rules live in [`CLARITY_RULES.md`](CLARITY_RULES.md). Code structure lives in [`PROJECT_STRUCTURE.md`](PROJECT_STRUCTURE.md).

## 1. Purpose

Clarity is a personal AI companion that remembers what matters to you and helps you stay on track with your life and money. You can talk to it naturally — especially while walking — and it understands, remembers, and supports you like a real friend.

**Shipping intent:** Real Plaid sync · Grok-powered Rex · voice-first design — personal finance that actually understands you. Rex only saves what you explicitly confirm. Every durable action is backend-verified — no fake memory, no invented balances, no hidden saves. Dark-first UI; English and Spanish at launch; more languages over time (does not block the brain cutover).

Clarity builds a confirmed relationship web around the people in your life — not only isolated person cards — so advice can use real connections and shared history the user has chosen to save.

## 2. Core Values

- Voice is the primary way of using Clarity. It must work excellently in the background while walking or moving.
- Rex must feel like a real, natural companion — calm, honest, and human.
- Memory and context must be reliable. If we've talked about something important, Rex should be able to find it.
- Social context must come from confirmed Knows data — never invented links or hidden graph facts.
- Trust is everything. Never lie, never fake success, never hide information.

## 3. Brain, body, and speech

| Layer | Role |
|-------|------|
| **Brain** | Grok as the **LLM** every chat and voice turn — understands and reasons. No long persona prompt. |
| **Speech out** | **Google TTS** speaks replies. Grok is not the TTS engine. |
| **Body** | Backend capabilities only — fetch data or mutate state after the brain decides. |
| **Gate** | Auto Suggestions (Off / Text / Card) plus kind toggles — applied **after** Grok’s meaning, not as language detectors. |

There is **no** second understanding layer of regex, phrase, overlap, or embedding brains that short-circuit Grok.

**Token budget:** a normal **base** turn aims for under ~1k tokens of model input (tiny system + thin state + recent chat). The turn may grow when tools, fetch, or heavy grounded packs are needed — situation-dependent, not always-on finance or Knows dumps.

**Capability catalog:** the system prompt lists short **names** of what the body can do (memory, people, goals, milestones, open threads, finance fetch/actions that match the app, chat search, and similar). There is **no** reply-length setting (concise / balanced / detailed) — Grok answers at a natural length.

## 4. Memory, Threads, Goals, and Chat History

### Saved Memory

Durable information saved in the Knows tab. Requires explicit user confirmation before saving (chat or voice). The user must be able to see, edit, or delete anything that is saved.

Saved Memory includes:

- **People** — person cards with light rolling **state** (who they are / current relational status) and related **notes**
- **Connections** — confirmed relationships between people (and between you and someone), not only a label on a card
- **Shared history** — confirmed multi-person events and moments
- **Named social groups** (e.g. “college friends”) — same person-card net family; confirm + visible in Knows (after Connections and Shared history)
- Other durable facts, preferences, places, and rules the user has saved

When a known person is mentioned, Rex may use related **confirmed** Connections and Shared history for advice. That context is still Saved Memory, not Chat History. Rex must not use relationship-web context in answers until those facts are visible and controllable in Knows.

Long detail lives in **chat search** when state and notes are not enough — not by stuffing hours of transcript into every turn.

Connections, Shared history, and (when shipped) named groups must appear in Knows and in saved-knowledge overview / inventory — they must not be hidden.

Clarity does **not** automatically create relationship edges from old chats or ops backfill. Every connection and shared-history item requires explicit user confirmation (or manual Knows save).

True duplicates of memories, goals, or related info are **deleted**, not archived as a soft hide.

### Goals

Clear objectives the user wants to achieve. Goals have a defined outcome (e.g. "Buy 32GB RAM for my computer", "Launch Clarity"). They have a beginning and an end. Plan-linked small steps are **milestones** under a goal.

### Open Threads

Lightweight accountability for habits and recurring behaviors (e.g. "Wake up at 4am", "Follow night routine", "Go to church on Sundays"). Rex will gently check in on these without the user needing to ask. Maximum 5 active threads.

### Chat History

Rex has access to all past conversations. When asked, it can search previous chats to recall what was discussed. Chat history is never treated as Connections or Shared history unless the user explicitly confirms a save into Knows.

## 5. Finance

The assistant may help with money the same ways the user can in the app: Plaid connect/sync, CSV import, categorize transactions, manage categories and budgets, and answer spend or account questions via **fetch** capabilities — not by dumping a full finance pack into every turn.

Rex does not invent balances, create transactions from thin air when the app only creates them via Plaid or CSV, or claim external-world actions (email, SMS, and similar) that the body cannot apply.

## 6. Voice vs Chat

Voice and chat share the exact same brain, memory, and rules. Rex should feel like the same person whether you're texting or speaking.
When listing items or showing data, Rex may format the response for better readability.

Relationship and shared-history saves use the same `write_proposals` confirm flow in voice and chat. There is no chat-only path for social graph writes.

## 7. Truth & Honesty

Rex can only claim something was "saved", "remembered", or "done" if the user can actually see it in the app. Nothing can be saved or stored secretly. The user must always have visibility and control over anything Rex saves.

API-only or database-only visibility is not enough — People, Connections, and Shared history must be visible in Knows before Rex treats them as remembered social context.

## 8. Tone

Calm, honest, supportive, and natural. Speak like a mature, trustworthy friend. Never shame the user. Tone comes from conversation and honesty — not from a long system-prompt personality essay.
