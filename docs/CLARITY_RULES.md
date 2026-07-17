# CLARITY_RULES.md

**Canon:** strict behavioral and technical rules for all AI agents working on Clarity.

Product vision: [`MASTER_PLAN.md`](MASTER_PLAN.md). Code paths and wiring: [`PROJECT_STRUCTURE.md`](PROJECT_STRUCTURE.md). Execution plans for the brain redesign: [`plans/`](../plans/) (01→05 only).

## Core Rules

### Always

- Make voice the primary and best experience
- Ensure Rex feels like a natural, calm, and honest companion
- Use **Grok as the understanding brain** for every chat and voice turn
- Apply **Auto Suggestions** (Off / Text / Card + kind toggles) only **after** structured intent/action from the brain — never as a language detector that skips Grok
- Keep the capability catalog aligned with real app features (including milestones and the person-card net when those surfaces exist)
- Keep default turn context **thin**; fetch finance, person context, recall, or inventory when needed
- Maintain strong, reliable memory and chat search
- Give global insight into the user's finances via fetch capabilities and confirmed actions
- Treat voice and chat equally for memory and relationship saves
- Enforce the Truth Rule on every reply

### Never

- Fake success, memory, or actions
- Save anything without making it visible to the user
- Hide information from the user
- Claim something was saved if the user cannot see, edit, or delete it
- Build or keep heuristic / regex / overlap / embedding **understanding** that short-circuits Grok
- Put personality essays in the system prompt to “create” Rex
- Force reply length (concise / balanced / detailed) that overrides natural Grok answers
- Always-on dump of full Knows or full finance into every base turn
- Claim email, SMS, or other external-world actions, or saves, without body apply this turn
- Invent relationship links, group dynamics, or social history
- Create relationship edges or shared-history records without explicit user confirmation
- Auto-generate connections from old conversations or ops backfill scripts
- Inject social-neighborhood context into prompts before those facts are visible in Knows
- Create duplicate relationship edges — merge or update instead
- Invent Connections / Shared history / groups or use them in answers before they are Knows-visible
- Add new planning docs under `docs/` outside the three hearts
- Archive competing plans or duplicate user data instead of **deleting** them when retiring

## When working on the assistant

- One pipeline, many capability handlers — Grok understands; the body executes
- Prefer deleting mismatching brain code over compatibility shims (see `plans/04_aggressive_deletion.md`)
- Follow `plans/01–05` in order for the brain redesign; do not invent parallel plan docs
- Base turn input aims under ~1k tokens; grow only when tools or fetch packs require it

## When working on Voice

- Ensure it works reliably in background mode
- Keep voice and chat using the exact same memory and reasoning system (same brain and body)
- Spoken replies use **Google TTS** — not Grok speech
- Relationship and social-event / shared-history proposals must be confirmable in voice via the same `write_proposals` path as chat
- Do not ship chat-only confirmation for People, Connections, or Shared history
- Native iOS voice bridge experiments must not become a second assistant pipeline

## When handling data

- Saved Memory must appear in Knows tab
- Goals belong in the Goals tab (achievement-oriented); milestones belong under goals
- Open Threads belong in Goals tab (habit/accountability, max 5)
- Always clearly separate Saved Memory, Goals, Open Threads, and Chat History
- People, Connections, Shared history, and named social groups are Saved Memory (Knows) — not Open Threads and not Chat History
- Connections and Shared history must appear in Knows and in saved-knowledge overview / inventory — do not hide them
- True duplicates of memories or goals are **deleted**, not archived as a soft hide

## When handling social / relationship memory

- **People** are person cards (nodes) in Knows, with light rolling state and notes as body capabilities
- **Connections** are confirmed edges between people (including you ↔ person) — never inferred-only links
- **Shared history** is confirmed multi-person events the user saved — never silent promotion from chat
- **Named social groups** are part of the same person-card net after Connections and Shared history are visible
- Neighborhood / cross-person context in the assistant may use only confirmed Connections and Shared history that the user can see and control in Knows
- Do not present chat co-mentions or search hits as saved Connections
- Do not invent introduction chains, conflicts, or group dynamics beyond what is saved
- Ship Knows visibility for Connections (and Shared history) before enabling social-neighborhood prompt injection
- `MemoryDisciplineService` (or equivalent discipline on the write path) must run before creating or updating relationships and shared events; duplicate active edges merge/update, never silently double-create
- Voice and chat use the same confirm → apply path for relationship and shared-history writes

## When the user asks about past conversations

- Search chat history (body capability)
- Do not confuse chat history with Saved Memory
- Do not treat chat history as Connections or Shared history unless the user confirms a Knows save

## Truth Rule (Highest Priority)

Never say "I saved it", "I remember", or "I did it" unless the user can see it in the app and control it.

For social context: never use relationship-web facts as remembered knowledge in Rex’s answers unless those People, Connections, and Shared history items are visible in Knows.
