# Plaid Mobile Real Account QA Report

Date created: 2026-06-08
Environment: Plaid production
Backend: `https://api.goclarity.app`
Mobile target: physical iOS device through `scripts/mobile_release_run.sh`

## Status

Overall status: Ready for real-device retest, not complete

This report replaces the earlier sandbox-device assumption for the mobile Plaid
plan. Phase 9 requires a real Plaid production connection with a real bank
account. Codex cannot perform the bank login or inspect private financial data,
so the physical-device results must be recorded by Pedro after running the app.

The previous timeout blocker has been addressed in code and configuration, but
the complete production lifecycle still needs one fresh physical-device pass:
Link success, `/plaid/exchange-token`, account creation, sync, UI refresh, CSV
fallback, and Assistant truth checks.

## 2026-06-08 Real Bank Timeout Finding

Pedro tested Plaid production Link on a physical iPhone with a real bank. Plaid
opened and showed real institutions, but Clarity returned to the Accounts empty
state with:

```text
Bank connection stopped before it finished. Plaid status: timeout.
```

VPS logs from the previous test window showed successful `/plaid/link-token`
requests, but no `/plaid/exchange-token` request. That means the backend can
create Link tokens, but mobile did not receive a Plaid success callback with a
public token.

Likely causes to validate:

- iOS OAuth redirect/Universal Link is not configured yet for production bank
  flows.
- The app may be losing Plaid's success/exit callback after the bank handoff.
- Android package name is irrelevant for the iPhone test, but must be configured
  before Android launch.

Fix applied in code:

- Backend Link token creation now sends documented mobile/OAuth fields when
  configured: `android_package_name`, `redirect_uri`, `webhook`, and optional
  `account_filters`.
- Link token creation is now platform-aware: iOS receives `redirect_uri`, while
  Android receives `android_package_name`.
- Backend defaults the iOS app identifier to `app.goclarity.clarity`.
- Backend logs safe link-token and public-token exchange milestones without
  logging tokens.
- Mobile logs sanitized `onEvent`, `onSuccess`, `onExit`, and timeout details.
- Mobile account parsing now reads the actual `plaid_item_record_id` account
  column used by the schema.
- Backend now serves the Apple App Site Association document for
  `7N42NS8B9B.app.goclarity.clarity` at
  `/.well-known/apple-app-site-association`.
- iOS Runner now has the `applinks:api.goclarity.app` Associated Domains
  entitlement.
- Mobile now listens for `https://api.goclarity.app/plaid/oauth` Universal Links
  while Plaid Link is open and passes them to
  `PlaidLink.resumeAfterTermination`.

Important Plaid API note:

- `ios_bundle_id` is retained as dashboard/readiness configuration, but it is
  not sent to `/link/token/create` because Plaid's documented iOS production
  mobile flow requires `redirect_uri` for OAuth return, not an
  `ios_bundle_id` JSON field.

## Automated Preflight

Completed on 2026-06-08:

- `flutter analyze`: Passed
- `flutter test test/plaid*`: Passed
- `VPS_SSH_TARGET=clarity ./scripts/mobile_release_run.sh --print`: Passed

Completed on 2026-06-09 after the real-bank fix phases:

- `cd services/rex-api && ./.venv/bin/python -m pytest -q tests/test_plaid_*.py`: Passed, 55 tests
- `cd apps/mobile && flutter analyze`: Passed
- `cd apps/mobile && flutter test test/plaid* test/budget_cleanup_service_test.dart test/assistant_financial_context_service_test.dart test/financial_integration_contracts_test.dart`: Passed, 26 tests
- `VPS_SSH_TARGET=clarity ./scripts/mobile_release_run.sh --print`: Passed and resolved the release run command from the VPS public mobile config

Completed on 2026-06-10 after official Plaid webhook verification hardening:

- `cd services/rex-api && ./.venv/bin/python -m pytest -q tests/test_plaid_*.py`: Passed, 59 tests
- `cd apps/mobile && flutter analyze`: Passed
- `cd apps/mobile && flutter test test/plaid* test/budget_cleanup_service_test.dart test/assistant_financial_context_service_test.dart test/financial_integration_contracts_test.dart`: Passed, 26 tests
- `VPS_SSH_TARGET=clarity ./scripts/mobile_release_run.sh --print`: Passed and resolved the physical-device release command

Scope covered by the 2026-06-09 preflight:

- Mobile Plaid success callback and public-token exchange path.
- Backend exchange route, item/account persistence, sync degradation behavior,
  cursor safety, and webhook tests.
- Dashboard/account/budget/assistant read-model alignment for Plaid-backed
  accounts and transactions.
- Budget cleanup and inactive category hiding before real-bank testing.

Known warning:

- `plaid_flutter` emits the accepted iOS Swift Package Manager warning. CocoaPods
  remains the current supported path for this plan.

Release helper note:

- Running `./scripts/mobile_release_run.sh --print` without `VPS_SSH_TARGET=clarity`
  failed because the helper defaults to `rex@209.126.87.50`, while the local SSH
  shortcut configured on this Mac is `clarity`.
- With `VPS_SSH_TARGET=clarity`, the helper resolved the public Supabase config
  from the VPS and printed a physical-device release command.

## Physical Device Test Command

Run from the repo root on the Mac with the iPhone connected:

```bash
VPS_SSH_TARGET=clarity ./scripts/mobile_release_run.sh
```

If you only want to inspect the generated command first:

```bash
VPS_SSH_TARGET=clarity ./scripts/mobile_release_run.sh --print
```

## VPS Log Watch Command

Run this in a separate VPS terminal before starting the Bank of America flow:

```bash
ssh clarity
sudo journalctl -u clarity-rex -f
```

For a successful connection, the log should show this sequence:

```text
POST /plaid/link-token
POST /plaid/exchange-token
Plaid public token exchange completed ... accounts=...
```

If `/plaid/link-token` appears but `/plaid/exchange-token` does not, the issue
is still in the mobile Plaid success/OAuth callback path. If
`/plaid/exchange-token` appears but the app stays empty, the issue is in
account persistence, sync, or mobile refresh.

## Real Account QA Checklist

Use one real bank account. Do not paste private account numbers, balances, or
transaction descriptions into this report. Record only pass/fail, counts,
latency, and sanitized notes.

| Step | Expected result | Result | Latency | Notes |
| --- | --- | --- | --- | --- |
| 1. Open Accounts or Dashboard and tap Connect Bank | Plaid Link opens | Ready to retest | Pending | Release command resolves successfully. |
| 2. Complete real bank login in Plaid Link | Link returns success to Clarity | Ready to retest | Pending | Previous timeout fixed in code; needs a fresh app install/run. |
| 3. Token exchange | Backend stores item securely and creates accounts | Ready to retest | Pending | Watch for `POST /plaid/exchange-token` in VPS logs. |
| 4. Initial sync | Accounts and recent transactions appear | Ready to retest | Pending | Verify checking and credit accounts separately. |
| 5. Status display | Account shows Connected and last synced timestamp | Ready to retest | Pending | Degraded/syncing is acceptable if first transaction sync is delayed. |
| 6. Manual resync | Resync completes without duplicate UI noise | Ready to retest | Pending | Use Accounts refresh/resync after initial connect. |
| 7. CSV fallback | Import CSV instead still works for a manual account | Ready to retest | Pending | Keep CSV as fallback only. |
| 8. CSV into Plaid-connected account | Calm duplicate-risk warning appears | Ready to retest | Pending | Do not import private CSV during this Plaid-only pass unless needed. |
| 9. Assistant financial truth | Assistant answers from connected accounts, transactions, and budgets | Ready to retest | Pending | Ask sanitized questions only; do not paste private balances into this report. |

## Data Checks

Record sanitized counts only:

- Connected institutions: Pending
- Connected accounts created: Pending
- Plaid transactions synced: Pending
- Plaid pending transactions shown or excluded according to UI rule: Pending
- Assistant can answer from Plaid-backed account/transaction/budget context:
  Pending
- Manual/CSV transactions imported during fallback check: Pending
- Duplicate warnings shown: Pending

## Phase 2 Physical QA Evidence To Capture

Record only sanitized evidence:

- Timestamp of the test run.
- Whether Plaid shows `HANDOFF - onSuccess`.
- Whether VPS logs show `POST /plaid/exchange-token`.
- Connected institutions count.
- Connected accounts count.
- Synced transaction count.
- Whether Dashboard leaves the "Connect your first bank" empty state.
- Whether Accounts shows both selected accounts with status and last synced
  state.
- Whether manual resync changes counts without creating visible duplicates.
- Whether Assistant can answer from the same connected account/transaction/budget
  data shown in Clarity.

## Security Checks

- Link token is short-lived and never persisted on mobile: Covered by code and
  tests; pending final production log review
- Public token is sent to backend only once for exchange: Covered by code and
  tests; pending final production log review
- Access token is never exposed to mobile/UI/logs: Covered by backend design,
  pending final production log review
- Plaid production keys are stored only in VPS environment: Passed readiness
  check before this report
- Apple App Site Association is served for `7N42NS8B9B.app.goclarity.clarity`:
  Passed prior VPS check

## Remaining Risks

- Real OAuth institution behavior remains unverified after the fix until the
  fresh physical-device pass is completed.
- The latest app build must be installed on the test iPhone before retesting
  Bank of America.
- `PLAID_WEBHOOK_URL` should be set to the public backend webhook endpoint before
  launch so Plaid can notify Clarity about item updates.
- Android package name and Android physical-device Link flow still need their
  own QA before Android launch.
- iOS `plaid_flutter` Swift Package Manager warning is accepted for now, but may
  become a future Flutter tooling blocker.
- Disconnect behavior is backend-supported, but mobile disconnect UI is not part
  of this validation path unless explicitly tested later.

## Completion Gate

Do not mark Phase 9 or the full mobile Plaid plan complete until all required
physical-device rows above are changed from Pending to Passed or documented with
known issues and an explicit ship/no-ship decision.
