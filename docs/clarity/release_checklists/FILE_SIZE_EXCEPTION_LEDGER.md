# File Size Exception Ledger

Last updated: June 3, 2026

## Purpose

This ledger records production files that currently exceed the Universal Code Architecture Standards size limits. Generated files are allowed only when listed as exceptions. Production files over 500 lines must have a follow-up cleanup phase or an explicit temporary exception.

## Scan Command

```bash
rg --files apps/mobile/lib services/rex-api/app apps/web/src supabase/functions \
  -g '*.dart' -g '*.py' -g '*.ts' -g '*.tsx' -g '*.astro' \
  | rg -v '\.(g|freezed)\.dart$' \
  | xargs wc -l \
  | awk '$1 > 500 && $2 != "total" {print $0}' \
  | sort -nr
```

## Generated Exceptions

| File | Lines | Reason | Cleanup trigger |
| --- | ---: | --- | --- |
| `apps/mobile/lib/features/assistant/chat/data/chat_models.freezed.dart` | 871 | Generated Freezed output | Regenerate only through source model changes |

## Production Cleanup Targets

| Priority | File | Lines | Follow-up phase | Notes |
| --- | --- | ---: | --- | --- |
| P1 | `apps/mobile/lib/features/transactions/presentation/widgets/transaction_category_dropdown.dart` | 773 | Phase 17 | Split UI from search/data behavior |
| P1 | `apps/mobile/lib/app/ui_dependencies.dart` | 757 | Follow-up after Phase 18 | App-level dependency registry needs review before splitting |
| P1 | `supabase/functions/categorize-transactions/index.ts` | 756 | Follow-up after Phase 17 | Edge function should split parser/prompt/client logic |
| P1 | `apps/mobile/lib/features/assistant/accountability/data/accountability_models.dart` | 690 | Phase 18 | Separate DTOs and presentation helpers where practical |
| P1 | `services/rex-api/app/services/entity_service.py` | 668 | Phase 15 | Split repository, normalization, and route-facing service |
| P1 | `apps/mobile/lib/features/dashboard/presentation/transaction_review_screen.dart` | 663 | Phase 17 | Extract review sections/widgets |
| P1 | `apps/mobile/lib/features/assistant/chat/presentation/pages/chat_page.dart` | 658 | Follow-up after Phase 19 | Chat UI still large and memory-state sensitive |
| P1 | `services/rex-api/app/services/plan_service.py` | 606 | Phase 15 | Split plan CRUD/policy/formatting |
| P2 | `apps/mobile/lib/features/accounts/presentation/account_selection_screen.dart` | 590 | Follow-up after finance cleanup | Account flow is stable but oversized |
| P2 | `apps/mobile/lib/features/accounts/presentation/accounts_screen.dart` | 588 | Follow-up after finance cleanup | Split account sections/widgets |
| P1 | `apps/mobile/lib/features/transactions/application/category_workflow_service.dart` | 553 | Phase 17 | Split workflow policy from persistence calls |
| P2 | `apps/mobile/lib/features/auth/presentation/mfa_enrollment_screen.dart` | 504 | Follow-up after launch-critical cleanup | Barely over limit; stable enough to defer |

## Current Rule

No new feature work should be added to the files above unless the work is part of their cleanup phase or a documented exception is added here.
