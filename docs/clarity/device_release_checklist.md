# Device Release Checklist

Use this checklist before treating a phone build as ready. The project has good
unit coverage, but recent issues were mostly device state, audio session, and
release configuration problems.

## Build Command

On the Mac, use the helper so the phone is not depending on a copied command
with stale flags:

```sh
./scripts/mobile_release_run.sh
```

The helper reads `SUPABASE_URL` and `SUPABASE_ANON_KEY` from your shell
environment or from `apps/mobile/.env`, points Rex at
`https://api.rexpilot.com`, and enables the supported streaming voice path.

Do not use `REX_NATIVE_IOS_VOICE_ENABLED` for normal testing.

To inspect the exact command before running it:

```sh
./scripts/mobile_release_run.sh --print
```

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
- Rex Brain readiness shows the expected routing/debug flags and configured model names.

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
10. Confirm the Assistant tabs render as one aligned row: Chat, Voice, Memory,
    Goals, and Chats. Chats should not appear as a detached header icon.
11. Switch through Chat, Voice, Goals, and Chats on the phone and confirm no
    tab overlaps the dynamic island, page title, content, composer, or bottom
    navigation.
12. Open Chats, select an existing conversation, and confirm the app returns to
    Chat with that conversation loaded.
13. Start voice from the Voice tab and confirm it uses the active conversation.
14. Focus the chat composer, show the keyboard, and confirm the composer stays
    visible and usable.
15. Start voice from the chat bar and complete at least five turns.
16. Confirm the user's live transcript appears while speaking.
17. Confirm Rex audio is audible at normal phone volume.
18. Confirm Rex does not cut itself off after speaking.
19. End the voice call and send a normal chat message in the same conversation.
20. Toggle `Deep Think` in Rex chat, send one planning/analysis message, and
    confirm the toggle clears after send.
21. Log out and sign back in; dashboard and account values should recover.

## Rex Brain Log Check

If `REX_BRAIN_ROUTING_ENABLED=true` on the VPS, confirm logs show metadata-only events:

```sh
sudo journalctl -u clarity-rex.service -n 200 --no-pager | grep rex_brain_turn
```

Expected log shape:

- Contains request id, channel, status, layer, model profile, latency class, and cost tier.
- Does **not** contain raw user message text, raw transaction rows, secrets, or prompt text.

## Failure Notes To Capture

For any failure, write down:

- Exact release command used.
- Backend `/ready` response.
- Startup log line beginning with `[Clarity][Config]`.
- Screen where the failure happened.
- Whether it happened after fresh install, force close, logout, or import.
