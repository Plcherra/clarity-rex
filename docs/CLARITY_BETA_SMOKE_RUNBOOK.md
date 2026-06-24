# Clarity Beta Smoke Runbook

Use this runbook for the real-device beta smoke pass. Automated backend and
Flutter tests are necessary, but this pass checks the trust-critical behavior
that only shows up on a phone: voice audio, navigation, Knows refresh, recall
wording, and finance no-guessing.

## Gate Rule

Do not proceed to beta with any known P0 failure:

- Rex claims a save, delete, or financial action succeeded when it did not.
- Rex guesses balances, transactions, merchants, budgets, or spending without
  reliable financial context.
- Voice reaches a dead-end where text appears but no recovery or audio path is
  available.
- Delete confirmation succeeds in chat but the item remains visible in Knows
  active-only view.
- Recall labels chat history as saved memory.

## Run Metadata

- Tester:
- Date/time:
- Device model:
- OS version:
- App build/version:
- API environment:
- API base URL:
- Test account:
- Network type: Wi-Fi / cellular / weak network
- Notes:

## Result Legend

- `[ ] PASS`
- `[ ] FAIL`
- `[ ] BLOCKED`
- `[ ] NOT RUN`

For every fail or blocked item, add a note using this format:

```text
Scenario:
Steps:
Expected:
Actual:
Screenshot/log:
Owner:
Severity: P0 / P1 / P2
```

## P0: Unified Voice In Chat

Goal: prove voice works as part of the same Chat session and returns to normal
typing.

- `[ ]` Start voice from the mic inside Chat.
- `[ ]` Speak a normal message.
- `[ ]` Confirm Rex replies in the same chat transcript.
- `[ ]` Confirm Rex speaks the reply aloud.
- `[ ]` While voice is active, type a reply.
- `[ ]` Confirm the typed reply appears in the same chat.
- `[ ]` Confirm Rex speaks the response to the typed reply.
- `[ ]` End voice.
- `[ ]` Send a normal typed message after ending voice.
- `[ ]` Confirm no crash, tab reset, duplicate conversation, or state loss.

Pass criteria:

- Chat and voice share one visible conversation.
- Voice can complete at least 5 consecutive mixed spoken and typed turns.
- Ending voice restores normal typing.
- No unrecoverable blank transcript, silent response, or stuck listening state.

## P0: Voice Latency And Gaps

Goal: catch audio gaps and listen/resume issues that unit tests cannot prove.

- `[ ]` Ask a short question.
- `[ ]` Confirm first audible response starts without a long delay.
- `[ ]` Ask a longer finance-shaped question, such as `How much did I spend this month?`.
- `[ ]` If financial context is unavailable or degraded, confirm Rex refuses to guess.
- `[ ]` Listen for mid-sentence pauses or missing chunks.
- `[ ]` Confirm Rex resumes listening after the spoken reply.
- `[ ]` Switch away from Chat while voice is active and note whether controls remain visible.

Pass criteria:

- Rex speaks every assistant response that appears on screen.
- Rex clearly refuses finance questions when reliable financial context is not
  available.
- The user can recover from any voice error with clear retry/end controls.

## P0: Delete To Knows

Goal: prove backend-confirmed delete is reflected in the Knows UI.

Setup:

- Save or seed: `User plans to watch it tonight.`

Steps:

- `[ ]` Ask Rex: `Can you delete that tonight plan?`
- `[ ]` Confirm with `Yes` if Rex asks.
- `[ ]` Confirm Rex only says it deleted the item after backend confirmation.
- `[ ]` Ask Rex: `Check what Clarity knows.`
- `[ ]` Open Knows.
- `[ ]` Enable or confirm active-only view.
- `[ ]` Confirm the deleted tonight plan is not visible.
- `[ ]` Confirm unrelated memories remain visible.

Pass criteria:

- The exact saved item is removed or deactivated.
- Rex does not claim deletion if the backend cannot confirm it.
- Knows active-only view matches the backend truth.

## P0: Recall Truth Labeling

Goal: prove Rex searches saved memory and old chats without confusing them.

Start from a new chat.

- `[ ]` Ask: `What do you know about my mom?`
- `[ ]` Ask: `Did I mention sending money or a gift to my mom?`
- `[ ]` Ask: `What games did I talk about?`
- `[ ]` Ask: `What was I buying for my first PC game?`
- `[ ]` Confirm useful old chat matches are surfaced when available.
- `[ ]` Confirm Rex says when it found chat history, not saved memory.
- `[ ]` Confirm Rex does not say it has saved memory unless the fact is truly saved.
- `[ ]` Confirm Rex says search is unavailable or degraded if search fails.

Pass criteria:

- Chat results are labeled as chat history.
- Saved memory is labeled separately.
- Rex does not answer "I do not know" if search failed or was not available.

## P0: Chats Search And Rex Recall Parity

Goal: prove Rex old-chat recall behaves like the Chats page search for arbitrary
topics while staying user-scoped.

Use a test account with old chats containing at least three of these topics:
`mom`, `payroll`, `immigration`, `PC`, `Legacy of Kain`, a place name, and one
random exact phrase.

- `[ ]` Open Chats and search `mom`; confirm matching old chats appear.
- `[ ]` Start a new chat and ask Rex: `What do you know about my mom?`
- `[ ]` Confirm Rex uses the same old-chat topic, not only saved memory.
- `[ ]` Search Chats for `payroll`, then ask Rex: `What did I say about payroll?`
- `[ ]` Search Chats for `immigration`, then ask Rex: `Anything about immigration?`
- `[ ]` Search Chats for `PC`, then ask Rex: `Can you look what kind PC I have?`
- `[ ]` Search Chats for one random exact phrase, then ask Rex about that phrase.
- `[ ]` Confirm Rex labels each retrieved item as chat history, not saved memory.
- `[ ]` Sign in as a second user and repeat one search term from the first user.
- `[ ]` Confirm the second user cannot retrieve the first user's chats.
- `[ ]` If Supabase access is available, verify the `search_user_chat_messages`
  RPC returns only rows scoped to the authenticated user.

Optional verifier from `services/rex-api`:

```powershell
$env:CLARITY_VERIFY_USER_A_TOKEN="<user-a-access-token>"
$env:CLARITY_VERIFY_USER_B_TOKEN="<user-b-access-token>"
python scripts/verify_chat_search_rpc.py --query "mom" --query "PC" --leak-query "<unique user A exact phrase>" --empty-query "<phrase neither user has>"
```

Pass criteria:

- Chats page search and Rex recall find the same topic families.
- Rex does not require topic-specific wording for mom, payroll, immigration, PC,
  names, places, or exact phrases.
- Cross-user search leakage is not possible.
- If indexed search is unavailable, Rex reports degradation instead of a clean
  "nothing came up" answer.

## P0: Finance No-Guessing

Goal: prove the backend finance truth guard works in the app, not only in tests.

- `[ ]` Ask a finance question while the app has reliable loaded financial context.
- `[ ]` Confirm Rex uses only records visible in Clarity context.
- `[ ]` Ask a finance question after forcing unavailable or degraded context if possible.
- `[ ]` Confirm Rex says it does not have reliable financial data and cannot answer without guessing.
- `[ ]` Confirm Rex does not invent account names, balances, merchants, budgets, or transaction history.

Suggested prompts:

- `How much did I spend this month?`
- `What is my checking account balance?`
- `What was my latest transaction?`
- `Can I afford to spend more this week?`

Pass criteria:

- Reliable context produces grounded answers.
- Missing or degraded context produces a refusal, not a guess.
- Financial answers match the same data the app shows.

## P1: Chats Filters And Search

- `[ ]` Open Chats.
- `[ ]` Test All.
- `[ ]` Test Today.
- `[ ]` Test This week.
- `[ ]` Test This month.
- `[ ]` Test Custom date range.
- `[ ]` Search while a date filter is active.
- `[ ]` Search for `18`.
- `[ ]` Search for `June 18`.
- `[ ]` Search for `Legacy of Kain`.
- `[ ]` Confirm empty states are understandable.

Pass criteria:

- Filters and search compose predictably.
- Empty states do not look like errors.
- Opening an old chat preserves the selected conversation.

## P1: Upload Picker And File Errors

- `[ ]` Tap the upload icon.
- `[ ]` Test Gallery image.
- `[ ]` Test Camera photo.
- `[ ]` Test Files with readable PDF.
- `[ ]` Test scanned or no-text PDF.
- `[ ]` Test oversized PDF if easy.
- `[ ]` Confirm errors are specific, not generic connection failures.

Pass criteria:

- Supported files attach successfully.
- Unsupported files explain the actual issue.
- Upload failure does not break typing or voice.

## P1: App Regression Quick Pass

- `[ ]` Send a normal text chat.
- `[ ]` Switch Assistant tabs.
- `[ ]` Open old chat from Chats.
- `[ ]` Check Knows page categories.
- `[ ]` Check Goals loads.
- `[ ]` Check Dashboard loads.
- `[ ]` Check Accounts loads.
- `[ ]` Check Budgets loads.

Pass criteria:

- No tab crashes.
- No blank critical screens.
- Dashboard, Accounts, Budgets, Assistant, Knows, Goals, and Chats remain usable.

## P2: Visual Polish Pass

- `[ ]` Check Dashboard.
- `[ ]` Check Accounts.
- `[ ]` Check Budgets.
- `[ ]` Check Assistant.
- `[ ]` Check Knows.
- `[ ]` Check Goals.
- `[ ]` Check Chats.
- `[ ]` Look for near-black theme consistency.
- `[ ]` Confirm text contrast is readable.
- `[ ]` Confirm Account rows are visually separable.

Pass criteria:

- No obvious light-theme leaks.
- Text is readable on device.
- Visual issues do not block trust-critical flows.

## Final Decision

- `[ ]` P0 all pass: beta can proceed to the next gate.
- `[ ]` P0 failed: fix before beta.
- `[ ]` P1/P2 issues only: decide whether to fix now or defer.

Final notes:

```text
Summary:
P0 failures:
P1 failures:
P2 issues:
Recommended next action:
```
