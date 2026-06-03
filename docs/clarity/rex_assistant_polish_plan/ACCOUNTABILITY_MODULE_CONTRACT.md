# Module Contract: Rex Accountability And Goals Intelligence

Status: Active

Owner: Pedro Martins / Clarity

Last updated: June 2, 2026

## Purpose

The accountability module helps Rex notice risks, follow-ups, plan drift, repeated patterns, and progress signals from the user's existing rules, commitments, plans, milestones, entity events, and saved memories. It should support helpful daily check-ins without inventing obligations or blocking normal chat.

## Scope

### In Scope

- Detect active rule risks from the current user message.
- Detect missed, due-today, stale, and completed commitment signals.
- Detect plan drift, upcoming milestones, missed plan dates, and plan progress.
- Detect repeated patterns using recent memories and entity events.
- Build `/accountability/*` API responses and overview buckets.
- Route plan-like memory candidates into plans, milestones, commitments, updates, or entity events.

### Out Of Scope

- Creating, approving, or deleting memories directly.
- Editing plans, milestones, commitments, or rules directly.
- Financial transaction syncing or Plaid ingestion.
- Voice capture, speech recognition, or TTS behavior.

## Users And Entry Points

| User/System | Entry Point | Expected Outcome |
| --- | --- | --- |
| Rex chat context | `AccountabilityService.analyze_signals(...)` | Returns active accountability signals for prompt context. |
| Mobile app | `GET /accountability/overview` | Returns grouped risks, open work, pending candidates, and cleanup warnings. |
| Mobile app | `GET /accountability/signals` | Returns filtered accountability signals. |
| Memory discipline | `PlanIntelligenceService.classify_plan_candidate(...)` | Routes plan candidates into the right durable structure. |

## Public API

| Name | Type | Responsibility |
| --- | --- | --- |
| `AccountabilityService` | Class | Coordinates rule, commitment, plan, and pattern detectors. |
| `PlanIntelligenceService` | Class | Routes plan-like candidates into stable plan hierarchy actions. |
| `/accountability/signals` | API | Lists filtered accountability signals. |
| `/accountability/rule-risks` | API | Lists active rule-violation signals. |
| `/accountability/plan-risks` | API | Lists plan drift and upcoming deadline signals. |
| `/accountability/patterns` | API | Lists repeated-pattern signals. |
| `/accountability/overview` | API | Lists overview buckets for the Assistant/Goals experience. |

## Data Ownership

### Reads

- Personal rules
- Commitments
- Plans
- Plan milestones
- Entities
- Entity events
- Relevant saved memories
- Pending memory candidates

### Writes

- None. This module is read-only and advisory.

### Does Not Touch

- Supabase auth sessions
- MFA settings
- Plaid items or transactions
- Memory approval state
- Voice stream state

## Dependencies

| Dependency | Direction | Reason |
| --- | --- | --- |
| Memory service | Outgoing | Reads rules, commitments, plans, events, memories, and candidates. |
| Time context service | Outgoing | Gives detectors current time and timezone. |
| Memory discipline service | Incoming | Uses plan intelligence classification. |
| Chat context service | Incoming | Uses accountability signals in Rex prompt context. |

## Main Flow

1. Endpoint or chat context requests accountability analysis for the current message.
2. Context loader reads user-scoped rules, plans, commitments, milestones, events, memories, and pending candidates.
3. `AccountabilityService` delegates detection to focused detector modules.
4. Route helpers filter, group, and render signals for the requested endpoint.
5. Overview builder returns grouped buckets and diagnostics without mutating durable data.

## Failure States

| Failure | User Impact | Handling |
| --- | --- | --- |
| Required memory list fails | Endpoint fails with memory service status. | Preserve `MemoryServiceError` status/detail. |
| Optional entity/candidate loader fails | Overview may omit optional rows. | Return loader diagnostics instead of silently swallowing the failure. |
| Detector throws | Endpoint returns 500. | Wrap as `Accountability analysis failed.` |
| No signals found | Rex should not invent issues. | Return empty signal lists and normal metadata. |

## Testing Contract

Required tests:

- Signal model validation and enum boundaries.
- Rule-risk detection.
- Commitment detection.
- Plan and milestone drift detection.
- Repeated-pattern detection.
- Route filtering, overview grouping, and error handling.
- Plan intelligence candidate routing.

Manual QA:

- Open Goals/Assistant views and confirm overview loads.
- Ask Rex for current accountability context and confirm it does not invent pending work.
- Confirm overview still loads when optional pending candidates are absent.

## File Ownership

Files owned by this module:

- `services/rex-api/app/services/accountability_service.py`
- `services/rex-api/app/services/accountability_shared.py`
- `services/rex-api/app/services/accountability_rule_risk.py`
- `services/rex-api/app/services/accountability_commitment_detector.py`
- `services/rex-api/app/services/accountability_plan_drift.py`
- `services/rex-api/app/services/accountability_pattern_detector.py`
- `services/rex-api/app/services/plan_intelligence_service.py`
- `services/rex-api/app/services/plan_intelligence_models.py`
- `services/rex-api/app/services/plan_intelligence_text.py`
- `services/rex-api/app/services/plan_intelligence_rules.py`
- `services/rex-api/app/services/plan_intelligence_payloads.py`
- `services/rex-api/app/routes/accountability.py`
- `services/rex-api/app/routes/accountability_context_loader.py`
- `services/rex-api/app/routes/accountability_signal_filters.py`
- `services/rex-api/app/routes/accountability_overview_builder.py`

Files this module may call but should not own:

- `services/rex-api/app/services/memory_service.py`
- `services/rex-api/app/services/time_context_service.py`
- `services/rex-api/app/services/memory_discipline_service.py`
- `services/rex-api/app/services/chat_context_service.py`

## Size And Refactor Guardrails

| File | Current Lines | Target | Hard Limit | Refactor Trigger |
| --- | ---: | ---: | ---: | --- |
| `accountability_service.py` | 95 | 120 | 500 | Adds detector logic directly. |
| `routes/accountability.py` | 138 | 160 | 500 | Adds non-endpoint data shaping. |
| `plan_intelligence_service.py` | 470 | 450 | 500 | Adds more helper/scoring logic directly. |
| `accountability_overview_builder.py` | 419 | 350 | 500 | Adds new warning families without extraction. |
| `plan_intelligence_rules.py` | 395 | 350 | 500 | Adds more heuristic groups without extraction. |

## Known Tradeoffs

| Tradeoff | Reason | Risk | Revisit When |
| --- | --- | --- | --- |
| Optional loaders return diagnostics instead of failing the whole overview. | Keeps the app usable when optional data is unavailable. | Missing optional rows can hide context. | Add observability dashboard or production alerting. |
| Heuristic routing stays deterministic. | Easier to test and safer before launch. | May miss semantic intent. | Add measured usage data or vector-backed matching. |
| Tests remain in large legacy files for now. | Runtime split was Phase 7 priority. | Test maintenance remains noisy. | Phase 10 test-suite split. |

## Open Questions

- Should loader diagnostics be surfaced in a developer-only mobile debug view?
- Should plan intelligence route decisions be logged for offline tuning?

## Acceptance Criteria

- [x] Accountability service delegates to focused detector modules.
- [x] Accountability routes delegate context loading, filtering, and overview building.
- [x] Plan intelligence is split into service, models, text helpers, rules, and payload builders.
- [x] Required runtime files stay under 500 lines.
- [x] Focused service, route, and plan intelligence tests pass.
- [ ] Manual QA complete on device.
