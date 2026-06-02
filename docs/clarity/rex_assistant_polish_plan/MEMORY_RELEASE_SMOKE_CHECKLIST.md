# Memory Release Smoke Checklist

Last updated: June 2, 2026

Purpose: verify the new Rex memory flow on a real phone before Plaid work resumes.
This checklist focuses only on whether memory feels natural, durable, and reliable.

## 1. Local Preflight

Run the memory reliability tests before deploying:

```bash
cd /Users/pedromartins/Desktop/clarity-rex/services/rex-api
python3 -m pytest tests/test_memory_reliability_flow.py -q
python3 -m pytest \
  tests/test_chat_simple_memory_flow.py \
  tests/test_memory_turn_service.py \
  tests/test_memory_profile_recall.py \
  tests/test_memory_retrieval.py \
  -q
```

Run the mobile memory label/card smoke tests:

```bash
cd /Users/pedromartins/Desktop/clarity-rex/apps/mobile
flutter test \
  test/memory_label_test.dart \
  test/chat_memory_candidate_card_test.dart \
  test/memory_api_test.dart
```

Pass condition:

- All tests pass.
- No hidden `rex_memory_confirmation` marker appears in test output or UI output.

## 2. Backend Deploy And Restart

On the VPS:

```bash
ssh rex@209.126.87.50
cd /opt/clarity/current
git config core.sshCommand "ssh -i ~/.ssh/id_ed25519_clarity"
git pull
./scripts/vps_restart_rex_api.sh
curl -s http://127.0.0.1:8011/ready | jq .
```

Pass condition:

- `clarity-rex.service` is active.
- `/ready` returns `status: ready`.
- Supabase, Grok, Deepgram, Google TTS, and Rex Brain checks are configured.

## 3. Phone Release Run

On the Mac:

```bash
cd /Users/pedromartins/Desktop/clarity-rex/apps/mobile
flutter devices
flutter pub get
flutter run --release -d <your-device-id>
```

Use a real logged-in user account. Keep the Memory tab openable during testing.

Pass condition:

- App launches on the phone.
- Assistant chat, voice, and Memory tab are reachable.
- Backend readiness stays healthy while testing.

## 4. Text Memory Save And Recall

In Rex text chat:

1. Say: `My mom's birthday is on the 18th.`
2. Rex should ask a natural confirmation question.
3. Say: `yes`
4. Ask: `Do you remember my mom's birthday?`

Expected result:

- Rex saves after the `yes`.
- Rex recalls June 18 from durable memory.
- The Memory tab shows one saved memory for the birthday.
- No duplicate pending memory card appears.

## 5. Voice Memory Save And Recall

In Rex voice mode:

1. Ask: `Do you remember my mom's birthday?`
2. If needed, also say: `Remember that my sister's birthday is July 10.`
3. Confirm naturally when Rex asks.
4. Ask again in voice.

Expected result:

- Voice recall uses the same durable memory store as text.
- Confirmed voice memories appear in the Memory tab.
- No hidden marker is spoken, displayed, or saved.

## 6. Correction Candidate Flow

In Rex text chat:

1. Say: `Actually my mom's birthday is June 19.`
2. Confirm that Rex treats this as a correction candidate, not an immediate silent overwrite.
3. Approve the correction in the Memory tab.
4. Ask: `Do you remember my mom's birthday?`

Expected result:

- Rex explains the pending correction clearly.
- After approval, Rex recalls June 19.
- The Memory tab shows one current saved memory for the birthday.
- The old June 18 record is archived or superseded and is not recalled.

## 7. Duplicate Prevention

In Rex text chat:

1. Say again: `My mom's birthday is June 19.`
2. Ask: `Are there any pending memories?`

Expected result:

- Rex does not create another pending card for the same topic.
- Rex should either say it is already saved or continue naturally without duplication.

## 8. Archive And Non-Recall

In the Memory tab:

1. Archive the saved birthday memory.
2. Ask in text: `Do you remember my mom's birthday?`
3. Ask the same in voice.

Expected result:

- Rex does not recall archived memory as active truth.
- The archived record remains visible only where archived/review history is expected.

## 9. Log Review

On the VPS:

```bash
journalctl -u clarity-rex.service -n 250 --no-pager | rg "memory_confirmation"
```

Expected lifecycle events:

- `memory_confirmation_requested`
- `memory_confirmation_direct_saved`
- `memory_confirmation_rejected` only when the user rejects
- `memory_confirmation_already_saved` when a duplicate fact is repeated

Failure signals:

- `memory_confirmation_save_failed`
- Repeated `memory_confirmation_requested` for the same topic after confirmation
- Any raw private memory content in logs

## 10. Release Decision

Pass Phase 10 only when:

- Text memory save and recall works.
- Voice recall works.
- Corrections go through pending review.
- Duplicate prevention works.
- Archived memory is not recalled.
- Backend logs show lifecycle events without private memory content.
- `/ready` remains healthy after the phone test.
