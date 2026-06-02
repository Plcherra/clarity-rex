# Module Contract: [Module Name]

Status: Draft / Active / Deprecated

Owner: [Name or team]

Last updated: [Date]

## Purpose

Describe the problem this module solves in plain language.

## Scope

### In Scope

- [Behavior, workflow, or responsibility included]
- [Data or user flow included]
- [Integration included]

### Out Of Scope

- [Responsibility intentionally excluded]
- [Workflow owned by another module]
- [Future capability not included yet]

## Users And Entry Points

| User/System | Entry Point | Expected Outcome |
| --- | --- | --- |
| [User or service] | [Function, screen, endpoint, job] | [Result] |

## Public API

List public functions, classes, providers, endpoints, or commands.

| Name | Type | Responsibility |
| --- | --- | --- |
| `[name]` | [Function/Class/API/Provider] | [What it does] |

## Data Ownership

### Reads

- [Table/API/model/config]

### Writes

- [Table/API/model/config]

### Does Not Touch

- [Explicit boundary]

## Dependencies

| Dependency | Direction | Reason |
| --- | --- | --- |
| [Module/service] | Incoming/Outgoing | [Why needed] |

## Main Flow

1. [Step 1]
2. [Step 2]
3. [Step 3]
4. [Step 4]

## Failure States

| Failure | User Impact | Handling |
| --- | --- | --- |
| [Failure case] | [What user sees] | [Retry/log/error behavior] |

## Testing Contract

Required tests:

- [Happy path]
- [Failure path]
- [Edge case]
- [Regression case]

Manual QA:

- [Manual step]
- [Expected result]

## File Ownership

Files owned by this module:

- `[path]`
- `[path]`

Files this module may call but should not own:

- `[path]`

## Size And Refactor Guardrails

| File | Current Lines | Target | Hard Limit | Refactor Trigger |
| --- | ---: | ---: | ---: | --- |
| `[path]` | [n] | [n] | [n] | [Trigger] |

## Known Tradeoffs

| Tradeoff | Reason | Risk | Revisit When |
| --- | --- | --- | --- |
| [Decision] | [Why] | [Risk] | [Trigger/date] |

## Open Questions

- [Question]
- [Question]

## Acceptance Criteria

- [ ] [Specific behavior works]
- [ ] [Failure case handled]
- [ ] [Tests pass]
- [ ] [Manual QA complete]
- [ ] [Docs updated]
