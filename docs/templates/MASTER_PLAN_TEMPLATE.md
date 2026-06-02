# Master Plan: [Project / Feature / Refactor Name]

Status: Draft / In Progress / Complete

Last updated: [Date]

## Purpose

Explain the goal, why it matters, and what success looks like.

## Core Outcome

By the end of this plan:

- [Outcome 1]
- [Outcome 2]
- [Outcome 3]

## Non-Goals

- [What this plan will not do]
- [What should be handled later]

## Current State

Summarize the current architecture, pain points, and risks.

| Area | Current State | Risk |
| --- | --- | --- |
| [Area] | [Description] | [Risk] |

## Target State

Describe the cleaner end state.

| Area | Target State | Benefit |
| --- | --- | --- |
| [Area] | [Description] | [Benefit] |

## Phase 1 - [Phase Name]

Goal: [One clear goal]

Files to change:

- `[path]`
- `[path]`

Steps:

1. [Step]
2. [Step]
3. [Step]
4. [Step]

Done looks like:

- [Observable outcome]
- [Code structure outcome]

Manual test steps:

1. [Step]
2. [Expected result]

Acceptance criteria:

- [ ] [Criterion]
- [ ] [Criterion]
- [ ] [Tests pass]

Line-count ledger:

| File | Before | After | Moved To |
| --- | ---: | ---: | --- |
| `[path]` | [n] | [n] | `[new path]` |

## Phase 2 - [Phase Name]

Goal: [One clear goal]

Files to change:

- `[path]`

Steps:

1. [Step]
2. [Step]
3. [Step]

Done looks like:

- [Observable outcome]

Manual test steps:

1. [Step]

Acceptance criteria:

- [ ] [Criterion]
- [ ] [Tests pass]

Line-count ledger:

| File | Before | After | Moved To |
| --- | ---: | ---: | --- |
| `[path]` | [n] | [n] | `[new path]` |

## Phase 3 - [Phase Name]

Goal: [One clear goal]

Files to change:

- `[path]`

Steps:

1. [Step]
2. [Step]
3. [Step]

Done looks like:

- [Observable outcome]

Manual test steps:

1. [Step]

Acceptance criteria:

- [ ] [Criterion]
- [ ] [Tests pass]

Line-count ledger:

| File | Before | After | Moved To |
| --- | ---: | ---: | --- |
| `[path]` | [n] | [n] | `[new path]` |

## Verification Commands

Backend:

```bash
[command]
```

Frontend/mobile:

```bash
[command]
```

Manual:

- [Manual QA item]

## Execution Order

1. Phase 1 - [Name]
2. Phase 2 - [Name]
3. Phase 3 - [Name]

## Release Gate

Ship only when:

- [ ] Focused tests pass
- [ ] Manual smoke test passes
- [ ] No file exceeds hard limits without documented exception
- [ ] Known risks are documented
- [ ] Rollback path is clear
