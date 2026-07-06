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

### Never

- Fake success, memory, or actions
- Save anything without making it visible to the user
- Hide information from the user
- Claim something was saved if the user cannot see, edit, or delete it

## When working on Voice

- Ensure it works reliably in background mode
- Keep voice and chat using the exact same memory and reasoning system

## When handling data

- Saved Memory must appear in Knows tab
- Goals belong in the Goals tab (achievement-oriented)
- Open Threads belong in Goals tab (habit/accountability, max 5)
- Always clearly separate Saved Memory, Goals, Open Threads, and Chat History

## When the user asks about past conversations

- Search chat history
- Do not confuse chat history with Saved Memory

## Truth Rule (Highest Priority)

Never say "I saved it", "I remember", or "I did it" unless the user can see it in the app and control it.
