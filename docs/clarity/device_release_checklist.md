# Device Release Checklist

Use this checklist before treating a phone build as ready. The project has good
unit coverage, but recent issues were mostly device state, audio session, and
release configuration problems.

## Build Command

Use one explicit release command so the phone is not depending on local `.env`
state:

```sh
cd apps/mobile
flutter run -d 00008150-000C03C83A2B401C --release \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key> \
  --dart-define=REX_BACKEND_URL=https://api.rexpilot.com \
  --dart-define=REX_CLOUD_VOICE_ENABLED=true \
  --dart-define=REX_STREAMING_VOICE_ENABLED=true
```

Do not use `REX_NATIVE_IOS_VOICE_ENABLED` for normal testing.

## Backend Check

On the VPS:

```sh
cd /opt/clarity/current
./scripts/vps_restart_rex_api.sh
```

Expected `/ready` result:

- `status` is `ready`.
- `service` is `clarity-rex`.
- `systemd_unit` is `clarity-rex.service`.
- Grok, Supabase, Deepgram, Google TTS, and timezone are configured.

## Phone Smoke Test

1. Delete the app from the phone and install the release build.
2. Sign in.
3. Confirm dashboard loads non-zero finance values after transactions exist.
4. Force close the app, reopen it, and confirm dashboard values are still
   present.
5. Open Accounts and confirm each account separates statement balance from
   monthly income, monthly spending, and monthly net.
6. Import a CSV and confirm the final message says all transactions were
   categorized when no unresolved rows remain.
7. Open Dashboard transaction Months, Categories, and Rows views.
8. Test category, account, history, sort, and role filters.
9. Open Rex chat and ask a finance question; Rex should not claim empty data
   when the dashboard has transactions.
10. Start voice from the chat bar and complete at least five turns.
11. Confirm the user's live transcript appears while speaking.
12. Confirm Rex audio is audible at normal phone volume.
13. Confirm Rex does not cut itself off after speaking.
14. End the voice call and send a normal chat message in the same conversation.
15. Log out and sign back in; dashboard and account values should recover.

## Failure Notes To Capture

For any failure, write down:

- Exact release command used.
- Backend `/ready` response.
- Startup log line beginning with `[Clarity][Config]`.
- Screen where the failure happened.
- Whether it happened after fresh install, force close, logout, or import.
