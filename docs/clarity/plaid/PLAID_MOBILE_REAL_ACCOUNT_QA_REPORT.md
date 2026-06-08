# Plaid Mobile Real Account QA Report

Date created: 2026-06-08
Environment: Plaid production
Backend: `https://api.goclarity.app`
Mobile target: physical iOS device through `scripts/mobile_release_run.sh`

## Status

Overall status: Pending manual physical-device validation

This report replaces the earlier sandbox-device assumption for the mobile Plaid
plan. Phase 9 requires a real Plaid production connection with a real bank
account. Codex cannot perform the bank login or inspect private financial data,
so the physical-device results must be recorded by Pedro after running the app.

## Automated Preflight

Completed on 2026-06-08:

- `flutter analyze`: Passed
- `flutter test test/plaid*`: Passed
- `VPS_SSH_TARGET=clarity ./scripts/mobile_release_run.sh --print`: Passed

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

## Real Account QA Checklist

Use one real bank account. Do not paste private account numbers, balances, or
transaction descriptions into this report. Record only pass/fail, counts,
latency, and sanitized notes.

| Step | Expected result | Result | Latency | Notes |
| --- | --- | --- | --- | --- |
| 1. Open Accounts or Dashboard and tap Connect Bank | Plaid Link opens | Pending | Pending |  |
| 2. Complete real bank login in Plaid Link | Link returns success to Clarity | Pending | Pending |  |
| 3. Token exchange | Backend stores item securely and creates accounts | Pending | Pending |  |
| 4. Initial sync | Accounts and recent transactions appear | Pending | Pending |  |
| 5. Status display | Account shows Connected and last synced timestamp | Pending | Pending |  |
| 6. Manual resync | Resync completes without duplicate UI noise | Pending | Pending |  |
| 7. CSV fallback | Import CSV instead still works for a manual account | Pending | Pending |  |
| 8. CSV into Plaid-connected account | Calm duplicate-risk warning appears | Pending | Pending |  |

## Data Checks

Record sanitized counts only:

- Connected institutions: Pending
- Connected accounts created: Pending
- Plaid transactions synced: Pending
- Manual/CSV transactions imported during fallback check: Pending
- Duplicate warnings shown: Pending

## Security Checks

- Link token is short-lived and never persisted on mobile: Pending manual
  confirmation
- Public token is sent to backend only once for exchange: Pending manual
  confirmation
- Access token is never exposed to mobile/UI/logs: Covered by backend design,
  pending final production log review
- Plaid production keys are stored only in VPS environment: Passed readiness
  check before this report

## Remaining Risks

- Real OAuth institution behavior is unverified until physical-device testing is
  completed.
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
