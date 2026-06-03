# Full Project Release Gate

Last updated: June 3, 2026

## Purpose

This checklist is the single release gate for Clarity + Rex after the 11/10 polish cleanup. Manual phone testing intentionally happens last, after automated checks, docs cleanup, file-size cleanup, and schema verification.

## 1. Local Automated Checks

Run from the repository root.

```bash
cd services/rex-api
.venv/bin/python -m pytest tests -q

cd ../../apps/mobile
flutter analyze
flutter test

cd ../web
npm run build
```

Expected result:

- Backend tests pass.
- Flutter analyze reports no issues.
- Flutter tests pass.
- Astro/web build completes.

## 2. File-Size Check

Production code scan:

```bash
rg --files apps/mobile/lib services/rex-api/app apps/web/src supabase/functions \
  -g '*.dart' -g '*.py' -g '*.ts' -g '*.tsx' -g '*.astro' \
  | rg -v '\.(g|freezed)\.dart$' \
  | xargs wc -l \
  | awk '$1 > 500 && $2 != "total" {print $0}' \
  | sort -nr
```

Generated files may exceed 500 lines only when documented. Production files over 500 lines must have a follow-up phase or explicit exception. The detailed ledger lives at `docs/clarity/release_checklists/FILE_SIZE_EXCEPTION_LEDGER.md` and is the source of truth for current line counts.

Known generated exception:

- `apps/mobile/lib/features/assistant/chat/data/chat_models.freezed.dart`

Known cleanup targets:

- `apps/mobile/lib/features/transactions/presentation/widgets/transaction_category_dropdown.dart`
- `apps/mobile/lib/app/ui_dependencies.dart`
- `supabase/functions/categorize-transactions/index.ts`
- `apps/mobile/lib/features/assistant/accountability/data/accountability_models.dart`
- `services/rex-api/app/services/entity_service.py`
- `apps/mobile/lib/features/dashboard/presentation/transaction_review_screen.dart`
- `apps/mobile/lib/features/assistant/chat/presentation/pages/chat_page.dart`
- `services/rex-api/app/services/plan_service.py`
- `apps/mobile/lib/features/accounts/presentation/account_selection_screen.dart`
- `apps/mobile/lib/features/accounts/presentation/accounts_screen.dart`
- `apps/mobile/lib/features/transactions/application/category_workflow_service.dart`
- `apps/mobile/lib/features/auth/presentation/mfa_enrollment_screen.dart`

## 3. Supabase Migration And RLS Verification

Use Supabase SQL editor or CLI-connected SQL.

```sql
select schemaname, tablename, rowsecurity
from pg_tables
where schemaname = 'public'
  and tablename in (
    'memory_confirmations',
    'memory_candidates',
    'long_term_memory',
    'memory_entities',
    'plans',
    'commitments'
  );
```

Expected:

- Every user-scoped table returns `rowsecurity = true`.
- Policies restrict user-owned access through `auth.uid() = user_id` or the table-specific equivalent.

## 3.5. Silent Failure Ledger Check

Before release, review `docs/clarity/release_checklists/SILENT_FAILURE_EXCEPTION_LEDGER.md`.

Required:

- P0 memory exception-handling items are fixed or explicitly deferred with a release blocker.
- P0 pending-review source-of-truth issues are fixed before manual memory testing.
- Voice long-form reliability risks are queued for the final phone test.

## 4. VPS Update And Restart

SSH:

```bash
ssh rex@209.126.87.50
cd /opt/clarity/current
git config core.sshCommand "ssh -i ~/.ssh/id_ed25519_clarity"
git pull
./scripts/vps_restart_rex_api.sh
```

Manual restart fallback:

```bash
cd /opt/clarity/current
sudo systemctl daemon-reload
sudo systemctl restart clarity-rex.service
sudo systemctl status clarity-rex.service --no-pager -l
curl -s http://127.0.0.1:8011/ready | jq .
```

Logs:

```bash
sudo journalctl -u clarity-rex.service --since "15 minutes ago" --no-pager -l
```

## 5. Mobile Release Install

Run from local Mac repo root.

```bash
./scripts/mobile_release_run.sh
```

If running directly:

```bash
cd apps/mobile
flutter run --release \
  --dart-define-from-file=.env
```

Expected:

- App launches.
- Supabase config is present.
- Rex API points to the VPS release backend.

## 6. Manual Device Tests

Run only after cleanup phases are complete.

Memory:

- Tell Rex: `My mom's birthday is June 18`.
- Confirm naturally in chat: `yes, save that`.
- Verify saved memory appears in Saved, not Pending.
- Ask: `Do you remember my mom's birthday?`
- Verify Rex recalls June 18.
- Verify pending count in chat matches Memory tab.
- Verify no duplicate pending birthday cards were created.

Voice:

- Short voice turn.
- Long-form explanation/dream-style voice turn.
- Screenshot/minimize/resume during voice.
- Earbuds/headphones route.
- Interrupt while Rex is speaking.
- Confirm no stuck "did not catch audio" banner.

Finance/import:

- Import CSV.
- Review dashboard transaction groups.
- Change a transaction category.
- Ask Rex a finance question that uses the read model.

Goals/accountability:

- Open Goals.
- Create or review a goal.
- Ask Rex about goal/accountability state.

## 7. Rollback

If the backend release breaks:

```bash
ssh rex@209.126.87.50
cd /opt/clarity/current
git log --oneline -5
git reset --hard <last-known-good-sha>
./scripts/vps_restart_rex_api.sh
```

Only use rollback after confirming the chosen SHA is the intended last-known-good release.

## 8. Known Non-Release Blockers To Track

- Flutter 3.44.1 warns that `permission_handler_apple` and `flutter_tts` do not support Swift Package Manager yet. This is not currently failing, but may become a future Flutter error.
- Plaid runtime integration is not implemented. Current Plaid service is a fail-closed skeleton and contract boundary only.
- Manual device tests are deferred until the cleanup phases are complete.
