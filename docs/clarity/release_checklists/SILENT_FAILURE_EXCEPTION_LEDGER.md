# Silent Failure And Exception Handling Ledger

Last updated: June 3, 2026

## Purpose

This ledger tracks broad exception handling in launch-sensitive Clarity + Rex flows. Broad catches are allowed only when they are deliberate circuit breakers with privacy-safe logging and a clear fallback. They are not allowed to make Rex claim that memory, voice, goals, reminders, or financial actions succeeded when they did not.

## Scan Command

```bash
rg -n "except Exception|catch \\(|catch \\{|catch \\(e|catchError|onError|pass$" \
  services/rex-api/app apps/mobile/lib supabase/functions \
  -g '*.py' -g '*.dart' -g '*.ts'
```

## Backend P0/P1 Review Targets

| Priority | Area | Files | Current risk | Required follow-up |
| --- | --- | --- | --- | --- |
| P0 | Memory direct-save/post-turn | `memory_post_turn_service.py`, `memory_turn_service.py`, `memory_intent_service.py` | Rex can sound confident while post-turn memory extraction/candidate cleanup fails in the background | Completed in Phase 13: explicit degraded metadata/logs and backend tests added |
| P0 | Pending review source of truth | `memory_candidate_review_session_service.py`, `memory_candidate_service.py`, `memory_candidate_writer.py` | Chat can disagree with Memory tab about pending count/state | Phase 19 must use one backend source for chat and tab counts |
| P0 | Memory correction/candidate writes | `memory_candidate_writer.py`, `memory_correction_service.py`, `memory_turn_confirmation_helpers.py` | Duplicate or stale candidates may survive after confirmation/correction | Phase 13 added write-failure logging; deeper dedupe/idempotency remains tracked in Phase 19 |
| P1 | Chat context degradation | `chat_context_service.py`, `rex_brain_chat_service.py` | Context failures can silently reduce Rex recall/quality | Keep fallback, but include structured degraded metadata |
| P1 | Voice session recovery | `voice_stream_session.py`, `voice_stream.py`, `voice.py` | Voice can fail or close without enough user-facing/debug context | Add long-form and reconnect/error tests in Phase 20 |
| P1 | Accountability/goal context | `accountability_context_loader.py`, `accountability_signal_filters.py`, `goal_context_service.py` | Accountability may degrade without clear reason | Add route/service tests for missing/degraded data |

## Backend Lower-Risk Review Targets

| Area | Files | Notes |
| --- | --- | --- |
| Structured memory normalization | `memory_structured_candidate_normalizer.py`, `memory_reference_resolver.py`, `memory_verification_service.py` | Many broad catches appear to be parser/normalizer tolerance; keep only with explicit fallback comments or tests |
| Rules/commitments/plans | `rule_service.py`, `commitment_service.py`, `plan_service.py` | Review during Phase 15 |
| Voice metadata parsing | `chat_voice_metadata.py` | Likely tolerant metadata parsing; document expected fallback |

## Mobile Review Targets

| Priority | Area | Files | Current risk | Required follow-up |
| --- | --- | --- | --- | --- |
| P0 | Voice long-form UX | `voice_call_controller_*`, `streaming_audio_capture_service.dart`, `streaming_voice_api.dart` | Voice can show "did not catch audio" and obscure chat after longer turns | Phase 20 should test timeout boundaries and error banner behavior |
| P1 | Memory actions | `memory_action_controller.dart`, `memory_read_controller.dart` | User-facing state must reflect failed save/reject/edit actions | Ensure all errors remain visible and reload state after actions |
| P1 | Finance/category workflows | `csv_import_service.dart`, `financial_read_model_service.dart`, `transaction_category_dropdown.dart` | Errors are mostly caught, but large files hide flow complexity | Review during Phase 17 |

## Supabase Function Review Targets

| Priority | Function | Risk | Required follow-up |
| --- | --- | --- | --- |
| P1 | `categorize-transactions` | Large edge function with multiple catch blocks | Split in follow-up after Phase 17 |
| P2 | `call-openai` | Generic catch blocks | Verify response errors are explicit enough |
| P2 | `send-mfa-security-email` | Email send failures should be visible in function logs | Verify production logs after release |

## Allowed Circuit Breaker Rules

A broad catch is allowed only if:

1. It prevents a larger user-facing flow from crashing.
2. It logs a privacy-safe reason or emits degraded metadata.
3. It does not claim a durable action succeeded.
4. It has a test or documented manual verification path.

## Next Action

Phase 13 completed the P0 silent-failure work for memory direct-save, post-turn extraction, and candidate creation. Phase 14 can proceed next. Phase 19 should handle pending-review source-of-truth disagreements, and Phase 20 should handle the voice long-form UX issues.
