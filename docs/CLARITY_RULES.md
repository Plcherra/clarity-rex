# CLARITY_RULES.md

**Canon:** strict behavioral and technical rules for all AI agents working on Clarity.

Product vision: [`MASTER_PLAN.md`](MASTER_PLAN.md). Code paths and wiring: [`PROJECT_STRUCTURE.md`](PROJECT_STRUCTURE.md).

## Core Rules

### Always

- Make voice the primary and best experience
- Ensure Rex feels like a natural, calm, and honest companion
- Maintain strong, reliable memory and chat search
- Give global insight into the user's finances
- Make Rex feel like a real companion
- Treat voice and chat equally for memory and relationship saves

### Never

- Fake success, memory, or actions
- Save anything without making it visible to the user
- Hide information from the user
- Claim something was saved if the user cannot see, edit, or delete it
- Invent relationship links, group dynamics, or social history
- Create relationship edges or shared-history records without explicit user confirmation
- Auto-generate connections from old conversations or ops backfill scripts
- Inject social-neighborhood context into prompts before those facts are visible in Knows
- Create duplicate relationship edges — merge or update instead

## When working on Voice

- Ensure it works reliably in background mode
- Keep voice and chat using the exact same memory and reasoning system
- Relationship and social-event / shared-history proposals must be confirmable in voice via the same `write_proposals` path as chat
- Do not ship chat-only confirmation for People, Connections, or Shared history

## When handling data

- Saved Memory must appear in Knows tab
- Goals belong in the Goals tab (achievement-oriented)
- Open Threads belong in Goals tab (habit/accountability, max 5)
- Always clearly separate Saved Memory, Goals, Open Threads, and Chat History
- People, Connections, and Shared history are Saved Memory (Knows) — not Open Threads and not Chat History
- Connections and Shared history must appear in Knows and in saved-knowledge overview / inventory — do not hide them

## When handling social / relationship memory

- **People** are person cards (nodes) in Knows
- **Connections** are confirmed edges between people (including you ↔ person) — never inferred-only links
- **Shared history** is confirmed multi-person events the user saved — never silent promotion from chat
- Neighborhood / cross-person context in the assistant may use only confirmed Connections and Shared history that the user can see and control in Knows
- Do not present chat co-mentions or search hits as saved Connections
- Do not invent introduction chains, conflicts, or group dynamics beyond what is saved
- Ship Knows visibility for Connections (and Shared history) before enabling social-neighborhood prompt injection
- `MemoryDisciplineService` (or equivalent discipline on the write path) must run before creating or updating relationships and shared events; duplicate active edges merge/update, never silently double-create
- Voice and chat use the same confirm → apply path for relationship and shared-history writes

## When the user asks about past conversations

- Search chat history
- Do not confuse chat history with Saved Memory
- Do not treat chat history as Connections or Shared history unless the user confirms a Knows save

## Truth Rule (Highest Priority)

Never say "I saved it", "I remember", or "I did it" unless the user can see it in the app and control it.

For social context: never use relationship-web facts as remembered knowledge in Rex’s answers unless those People, Connections, and Shared history items are visible in Knows.
