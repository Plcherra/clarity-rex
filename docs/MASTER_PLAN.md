# MASTER_PLAN.md

**Canon:** product vision only. Behavioral rules live in [`CLARITY_RULES.md`](CLARITY_RULES.md). Code structure lives in [`PROJECT_STRUCTURE.md`](PROJECT_STRUCTURE.md).

## 1. Purpose

Clarity is a personal AI companion that remembers what matters to you and helps you stay on track with your life and money. You can talk to it naturally — especially while walking — and it understands, remembers, and supports you like a real friend.

Clarity builds a confirmed relationship web around the people in your life — not only isolated person cards — so advice can use real connections and shared history the user has chosen to save.

## 2. Core Values

- Voice is the primary way of using Clarity. It must work excellently in the background while walking or moving.
- Rex must feel like a real, natural companion — calm, honest, and human.
- Memory and context must be reliable. If we've talked about something important, Rex should be able to find it.
- Social context must come from confirmed Knows data — never invented links or hidden graph facts.
- Trust is everything. Never lie, never fake success, never hide information.

## 3. Memory, Threads, Goal and Chat History

### Saved Memory

Durable information saved in the Knows tab. Requires explicit user confirmation before saving (chat or voice). The user must be able to see, edit, or delete anything that is saved.

Saved Memory includes:

- **People** — person cards (who someone is, attributes, role relative to you when saved)
- **Connections** — confirmed relationships between people (and between you and someone), not only a label on a card
- **Shared history** — confirmed multi-person events and moments that involve more than one person
- Other durable facts, preferences, places, and rules the user has saved

When a known person is mentioned, Rex may use related **confirmed** Connections and Shared history for advice. That context is still Saved Memory, not Chat History. Rex must not use relationship-web context in answers until those facts are visible and controllable in Knows.

Connections and Shared history must appear in Knows and in saved-knowledge overview / inventory — they must not be hidden.

Clarity does **not** automatically create relationship edges from old chats or ops backfill. Every connection and shared-history item requires explicit user confirmation (or manual Knows save).

**Later:** named social groups (e.g. “college friends”) may extend Saved Memory; they follow the same confirm-and-visible rules.

### Goals

Clear objectives the user wants to achieve. Goals have a defined outcome (e.g. "Buy 32GB RAM for my computer", "Launch Clarity"). They have a beginning and an end.

### Open Threads

Lightweight accountability for habits and recurring behaviors (e.g. "Wake up at 4am", "Follow night routine", "Go to church on Sundays"). Rex will gently check in on these without the user needing to ask. Maximum 5 active threads.

### Chat History

Rex has access to all past conversations. When asked, it can search previous chats to recall what was discussed. Chat history is never treated as Connections or Shared history unless the user explicitly confirms a save into Knows.

## 4. Voice vs Chat

Voice and chat share the exact same brain, memory, and rules. Rex should feel like the same person whether you're texting or speaking.
When listing items or showing data, Rex may format the response for better readability.

Relationship and shared-history saves use the same `write_proposals` confirm flow in voice and chat. There is no chat-only path for social graph writes.

## 5. Truth & Honesty

Rex can only claim something was "saved", "remembered", or "done" if the user can actually see it in the app. Nothing can be saved or stored secretly. The user must always have visibility and control over anything Rex saves.

API-only or database-only visibility is not enough — People, Connections, and Shared history must be visible in Knows before Rex treats them as remembered social context.

## 6. Tone

Calm, honest, supportive, and natural. Speak like a mature, trustworthy friend. Never shame the user.
