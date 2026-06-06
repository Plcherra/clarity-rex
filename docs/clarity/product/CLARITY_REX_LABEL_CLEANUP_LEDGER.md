# Clarity Rex Label Cleanup Ledger

Status: Phase 3 product-label cleanup ledger  
Last updated: 2026-06-06  
Source contract: `docs/clarity/product/CLARITY_PRODUCT_VOCABULARY.md`

## Executive Summary

Phase 3 removed the obvious active product-shell copy that made Clarity read like "Clarity plus a separate Rex app." Rex remains allowed only as the assistant's conversational personality or voice name. Deeper implementation names such as `rex_*` files, `RexApiClient`, and brain/router classes remain intentionally out of scope for this phase unless they leak to users.

## Resolved Active Product-Shell Violations

| Previous label | New label | File | Owning phase |
| --- | --- | --- | --- |
| `Rex Backend` | `Clarity API` | `services/rex-api/app/main.py` | Phase 3 |
| `Message Rex...` | `Message Assistant...` | `apps/mobile/lib/features/assistant/chat/presentation/widgets/chat_input_bar.dart` | Phase 3 |
| `Search what Rex knows` | `Search what Clarity knows` | `apps/mobile/lib/features/assistant/memory/presentation/widgets/memory_page_header_widgets.dart` | Phase 3 |
| `What Rex knows` | `What Clarity knows` | `apps/mobile/lib/features/assistant/memory/presentation/widgets/memory_page_header_widgets.dart` | Phase 3 |
| `What Rex Knows` | `What Clarity Knows` | `apps/mobile/lib/features/assistant/memory/presentation/pages/memory_page.dart` | Phase 3 |
| `Rex Memory` error copy | `saved information` | `apps/mobile/lib/features/assistant/memory/application/memory_controller_errors.dart` | Phase 3 |
| `Rex backend returned...` | `Clarity API returned...` | assistant API client error files | Phase 3 |
| `Rex will stop using...` | neutral saved-information copy | `apps/mobile/lib/features/assistant/memory/presentation/widgets/memory_archive_dialogs.dart` | Phase 3 |

## Allowed Rex Conversational Usage

These uses are intentionally allowed because they refer to the assistant personality, voice interaction, or implementation internals rather than a separate product:

| Pattern | Why allowed | Later owner |
| --- | --- | --- |
| Assistant says `I'm Rex` in the empty chat transcript | Conversational identity | Assistant Intelligence Phase 7 if trust copy changes |
| Chat title fallback `Rex` | Conversation/personality label | Unified Product Shell Phase 3 |
| Tooltips like `Call Rex` or `Interrupt Rex` | Voice/personality action | Assistant Intelligence Phase 3 |
| Voice state copy like `Rex is finishing...` | Personality-specific voice state | Assistant Intelligence Phase 8 |
| Prompt text `Rex is Clarity's...` | System prompt/personality contract | Assistant Intelligence Phase 1 |
| `rex_*`, `RexApiClient`, `RexBrain*`, `RexUiTokens` | Internal implementation names | Design System Phase 3 / Assistant Intelligence Phase 4 |
| Historical docs and migrations | Historical record, not active product UI | Release Validation Phase 1 |

## Remaining Implementation-Level Cleanup

| Area | Current state | Owner |
| --- | --- | --- |
| Assistant tokens and surfaces | `RexUiTokens`, `RexScaffold`, and `RexSurface` remain implementation names. | `CLARITY_DESIGN_SYSTEM_MASTER_PLAN.md` Phase 3 |
| Backend package/service names | `services/rex-api`, `rex_brain_*`, and `RexApiClient` remain internal names. | `CLARITY_ASSISTANT_INTELLIGENCE_MASTER_PLAN.md` Phase 4 |
| Assistant voice personality copy | Some voice UX strings intentionally say Rex. | `CLARITY_ASSISTANT_INTELLIGENCE_MASTER_PLAN.md` Phase 3 and Phase 8 |
| Historical architecture snapshot | Phase 1 snapshot still describes previous drift. | Keep as historical snapshot |

## Banned-Term Scan Result

After Phase 3 cleanup, the strict active-code scan for old product labels should return no active app/backend results:

```bash
rg -n "Rex app|Rex Backend|What Rex knows|What Rex Knows|Message Rex|Rex knows this|pending memory|memory candidate|MemoryCandidate|review session|candidate card|review before saving|Save this only after approval" apps/mobile/lib services/rex-api/app
```

Plan docs may still mention old terms as banned labels, acceptance criteria, or historical context. Those are not product-shell violations.

## Phase Handoff

Phase 4 should define shared Clarity read models. Deeper implementation renames should wait until the owning subsystem plans so we do not create churn before the shared data contracts are stable.
