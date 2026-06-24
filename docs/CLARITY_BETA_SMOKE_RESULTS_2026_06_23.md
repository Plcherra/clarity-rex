# Clarity Beta Smoke Results - 2026-06-23

Source runbook: `docs/CLARITY_BETA_SMOKE_RUNBOOK.md`

Tester report captured from real-device/manual smoke testing. This is not a
replacement for automated tests; it records device behavior that must guide the
next beta hardening work.

## Final Decision

- `[ ]` P0 all pass: beta can proceed to the next gate.
- `[x]` P0 failed: fix before beta.
- `[ ]` P1/P2 issues only: decide whether to fix now or defer.

Beta should not proceed until the P0 trust and voice failures below are fixed or
explicitly accepted as known blockers.

## P0 Results

### Unified Voice In Chat

Result: `PASS`, with later-session voice regression.

Notes:

- Unified voice in Chat worked perfectly during the main P0 voice test.
- Later in the same smoke pass, voice stopped working while text chat continued
  displaying assistant responses.

Risk:

- The basic voice loop works, but long-session or post-recall/post-finance state
  may still break spoken output.

Follow-up:

- Add a focused repro around longer conversations: recall questions, finance
  refusal, then another voice turn.
- Verify whether the stream still sends `assistant.audio_chunk` after the point
  where visible text continues but speech stops.

### Delete To Knows

Result: `PASS AFTER FIX`.

Observed:

- Initial smoke failed: Rex claimed there was no saved memory, and also claimed
  it saved a memory while nothing appeared in Knows.
- Follow-up device check now shows memory information is fixed: Rex says what is
  saved into the Knows tab.

Risk:

- This P0 is no longer the top active blocker, but it should remain in regression
  checks because durable memory truth is high risk.

Follow-up:

- Keep save -> Knows visible -> delete -> Knows hidden in the manual smoke pass.
- Add or keep an integration test for the same loop.

### Recall Truth Labeling

Result: `PARTIAL FAIL`.

Observed:

- Rex remembered the user's mom's birthday.
- Rex remembered that sending money to mom had been mentioned.
- Rex did not retrieve how much money or by what day, even though the user had
  specified an amount and date for the birthday.
- When asked why money would be sent and how much, Rex could not answer.
- Running a new search for mom's birthday found related evidence again.
- Rex remembered the games mentioned.
- Follow-up screenshot still shows old-chat PC recall failing: the user asked
  `From our old chat, can you say what kind of computer, what PC I have?`, and
  Rex answered `I don't have any info saved about your computer or PC from our
  chats.`

Risk:

- Recall is working, but ranking/excerpt assembly is not sharp enough for
  multi-fact recall around the same entity/event.
- Truth wording is still too loose when old chat search is empty or misses; Rex
  should not conflate saved memory with old-chat search.

Follow-up:

- Test recall with compound queries around mom, birthday, money amount, and due
  date.
- Check whether chat search finds the right message but excerpt/ranking drops
  the amount/date.
- If the Chats tab can find the exact message, Rex recall should include enough
  surrounding text to answer the amount/date question or clearly say it found
  only partial evidence.
- Treat old-chat search as a real user-scoped product feature: when the user asks
  about older chats, Rex must search all conversations for that authenticated
  user, not rely on saved memory or phrase-specific fallbacks.

### Finance No-Guessing

Result: `FAIL / BLOCKED`.

Observed:

- Rex said it had nothing from finance saved and could not look into finances.

Interpretation:

- Backend no-guessing behavior appears to be protecting against hallucination,
  but the app did not provide reliable financial context for a normal finance
  question.
- The wording may also be confusing saved memory with live financial context.

Risk:

- Clarity's finance promise is blocked if Rex cannot access the same financial
  data the app shows.

Follow-up:

- Verify mobile is attaching `financial_context` for finance turns.
- Verify `assistantFinancialContextServiceProvider` is present in the running
  app.
- Verify the context has `data_status.state=ready`,
  `financial_context_complete=true`, and no `load_errors`.
- Improve refusal copy if needed so Rex says "financial data is unavailable this
  turn" rather than implying finances should be saved memory.

## P1 Results

### Chats Filters And Search

Result: `PASS`.

Observed:

- All tested filters and search worked well.

Follow-up:

- Performance and organization can still improve: first Chats open takes a bit
  because many chats load at once.
- Consider loading recent chats first, then filtering/searching older history on
  demand.

### Upload Picker And File Errors

Result: `PARTIAL FAIL`.

Observed:

- Gallery images worked and Rex gave useful insight.
- Upload UI felt extremely ugly and primitive.
- PDF upload failed with generic copy: `could not upload the file. check your
  connection and try again.`

Risk:

- Image upload is functional, but PDF failure copy points users to the wrong
  cause and makes debugging hard.

Follow-up:

- Split PDF failure causes: unreadable/no-text PDF, oversized file, unsupported
  file, backend parse failure, and network failure.
- Improve upload picker presentation as a later UI task.

### App Regression Quick Pass

Result: `PARTIAL FAIL`.

Observed:

- Text chat works, but voice and text sometimes behave oddly.
- Voice transcription sometimes duplicates the spoken message in displayed
  transcript text.
- Sending a text message usually takes around 4 seconds before it really sends.
- During that delay, the send button animates and the text remains locked in the
  input box.
- Chats page takes time on first open because it loads many chats at once.

Risk:

- These are not all P0 individually, but they make the assistant feel slow and
  unreliable.

Follow-up:

- Investigate duplicate transcript rendering in voice state/UI.
- Measure where the 4-second text-send delay occurs: financial context build,
  memory/context fetch, network request, or UI state handling.
- Optimistically clear/send user text if backend call is in flight, as long as
  failure recovery remains clear.
- Load recent chats first and defer older history.

## P2 Results

### Visual Polish Pass

Result: `FUNCTIONAL PASS / PRODUCT POLISH FAIL`.

Observed:

- UI is consistent and unified across the app.
- Financial area is acceptable for building but still feels basic.
- Assistant area feels like a primitive bot UI, not like a modern assistant such
  as Grok or ChatGPT.
- Yellow primary color does not feel ideal; baby blue was suggested as a future
  primary color direction.
- Upload UI is especially primitive.

Risk:

- Not a beta trust blocker, but not acceptable as final product polish.

Follow-up:

- Create a lower-priority UI modernization plan after P0/P1 reliability is
  stable.
- Keep this separate from trust fixes so visual redesign does not destabilize
  memory, recall, finance, or voice.

## Recommended Next Work

Do not move directly to broad frontend polish. Fix P0 blockers first:

1. **Memory Save/Delete To Knows Fix Pack**
   - Status: improved after follow-up device check.
   - Keep in regression: prove save appears in Knows before proving delete hides
     it.

2. **Finance Context Bridge Fix Pack**
   - Confirm mobile sends ready financial context on finance turns.
   - Keep backend no-guessing guard.
   - Improve copy so finance context is not described as saved memory.

3. **Voice Long-Session Reliability Fix Pack**
   - Reproduce text-visible/audio-stopped behavior after several recall/finance
     turns.
   - Verify audio chunk events and mobile playback state.

4. **Recall Sharpness Fix Pack**
   - Improve mom birthday + money amount/date recall.
   - Build and verify all-conversation, user-scoped old-chat search for generic
     "what did we talk about" questions.
   - Preserve truth labeling: chat history is not saved memory.

5. **P1 Assistant Performance And Upload Errors**
   - Text send latency.
   - Duplicate transcription display.
   - PDF-specific error handling.
   - Recent-first Chats loading.

6. **P2 UI Modernization Plan**
   - Assistant UI modernization.
   - Upload UI polish.
   - Color direction exploration, including baby blue.
   - Finance UI upgrade after reliability.
