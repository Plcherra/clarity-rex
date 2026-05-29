# File 10 - Final Testing & Release Readiness

Goal: provide the final release gate for Rex Assistant polish, including automated tests, manual phone scenarios, backend readiness, VPS rollout, mobile release, rollback, and signoff.

Working rule: this file does not add major new product behavior. It validates, hardens, documents, and releases the Assistant polish work completed in Files 01-09.

## Phase 1 - Build Assistant Release Test Matrix

Goal: define the full set of automated and manual scenarios required before release.

Files to modify / create:

- `docs/clarity/device_release_checklist.md`
- `docs/clarity/rex_assistant_polish_plan/10_testing_release_readiness.md`
- Optional: `docs/clarity/rex_assistant_polish_plan/10_testing_release_notes.md`

Acceptance criteria:

- Matrix covers Chat, Voice, Memory, Goals, Chats, Deep Think, empty states, errors, and navigation.
- Matrix marks automated, manual, real-device, and VPS-only checks.
- Manual checks list expected outcomes.
- No production behavior changes.

Risks & mitigations:

- Risk: checklist becomes too broad to use.
- Mitigation: separate smoke tests from extended regression tests.

Effort: Small.

## Phase 2 - Automated Test Gate

Goal: make the minimum automated test commands explicit and repeatable.

Files to modify / create:

- `docs/clarity/device_release_checklist.md`
- `scripts/` only if a helper script is clearly useful
- Existing test docs

Acceptance criteria:

- Commands include backend pytest, Flutter analyze, relevant Flutter tests, and `git diff --check`.
- Test gate states what failures block release.
- If tests are skipped, the checklist requires a written reason.
- Commands work from documented directories.

Risks & mitigations:

- Risk: release depends on memory of commands.
- Mitigation: put exact commands in the checklist.

Effort: Small.

## Phase 3 - Backend Readiness And VPS Gate

Goal: ensure the Rex API is deployed, configured, and observable before phone testing.

Files to modify / create:

- `docs/deployment.md`
- `docs/clarity/device_release_checklist.md`
- `scripts/vps_restart_rex_api.sh` only if readiness gaps remain

Acceptance criteria:

- VPS steps include `git pull`, restart script, and readiness response check.
- Readiness confirms Grok, Rex Brain, Supabase, Deepgram, Google TTS, and time config.
- Rollout flags and safe defaults are documented.
- Journal/log command is included for voice failure debugging.

Risks & mitigations:

- Risk: testing mobile against stale backend.
- Mitigation: require readiness timestamp after pull/restart before phone run.

Effort: Small.

## Phase 4 - Mobile Release Script Gate

Goal: make phone install/release steps predictable and less error-prone.

Files to modify / create:

- `scripts/mobile_release_run.sh`
- `apps/mobile/README.md`
- `docs/clarity/device_release_checklist.md`

Acceptance criteria:

- Release script validates required env before build.
- Script command is documented from repo root.
- Expected connected-device behavior is documented.
- Common failure causes are listed: missing env, device locked, signing, stale backend URL.

Risks & mitigations:

- Risk: release script hides important build flags.
- Mitigation: print or document the resolved safe non-secret config.

Effort: Small.

## Phase 5 - Manual Phone Smoke Test

Goal: verify the core Assistant flow on a real iPhone.

Files to modify / create:

- `docs/clarity/device_release_checklist.md`
- Optional manual test report file after execution

Acceptance criteria:

- Test covers Assistant tab alignment, Chat send, Deep Think send, Voice call, Memory review, Goals overview, Chats resume, and keyboard behavior.
- Test covers iPhone safe areas and bottom nav.
- Any failure has screenshot, exact steps, and whether it blocks release.
- No release approval without this manual pass or explicit deferral.

Risks & mitigations:

- Risk: manual testing is skipped because automated tests are green.
- Mitigation: mark real-device smoke as required for Assistant release.

Effort: Medium.

## Phase 6 - Voice Extended Device Test

Goal: validate the highest-risk Voice paths beyond the basic smoke test.

Files to modify / create:

- `docs/clarity/device_release_checklist.md`
- Optional manual voice report

Acceptance criteria:

- Test covers microphone permission, listening transcript, final transcript, Rex response, retry, end call, interruption, background app, YouTube/music interruption, earbuds/Bluetooth, and poor network if practical.
- Voice failures include `journalctl` capture steps.
- Success/failure rate is recorded across retry scenarios.
- Any voice blocker is fixed or documented before release.

Risks & mitigations:

- Risk: Bluetooth behavior varies by device.
- Mitigation: document device model, iOS version, and audio route used.

Effort: Medium.

## Phase 7 - Data Integrity And Privacy Check

Goal: verify Assistant polish did not expose private internals or corrupt user data.

Files to modify / create:

- `docs/clarity/device_release_checklist.md`
- Backend/mobile tests if gaps are found

Acceptance criteria:

- No raw backend labels visible in Assistant UI.
- Memory approve/reject/edit flows do not silently mutate without confirmation.
- Goals does not show memory candidate internals.
- Logs avoid raw transcript/audio and private financial/memory content.
- Chat/Voice preserve conversation persistence.

Risks & mitigations:

- Risk: UI looks clean but logs leak private content.
- Mitigation: include a targeted log/privacy review in release gate.

Effort: Medium.

## Phase 8 - Rollback Plan

Goal: define what to do if phone testing or production testing finds a blocker.

Files to modify / create:

- `docs/deployment.md`
- `docs/clarity/device_release_checklist.md`

Acceptance criteria:

- Backend rollback includes env flag rollback and service restart.
- Mobile rollback path is documented as reinstall previous known-good build or revert/ship hotfix.
- Rex Brain can be disabled without reverting the app.
- Voice-specific rollback/log collection steps are included.

Risks & mitigations:

- Risk: panic changes on VPS.
- Mitigation: prefer flags and restart before code rollback when possible.

Effort: Small.

## Phase 9 - Final Signoff And Known Issues

Goal: close the Assistant polish project with a clear release decision.

Files to modify / create:

- `docs/clarity/device_release_checklist.md`
- Optional release report file
- `docs/clarity/rex_assistant_polish_plan/10_testing_release_readiness.md`

Acceptance criteria:

- Automated test results are recorded.
- Manual phone results are recorded.
- Known issues are classified as blocker, high, medium, low, or accepted.
- Release decision is explicit: ship, hold, or ship with documented limitations.
- Next-phase ideas are moved out of the release gate.

Risks & mitigations:

- Risk: endless polish prevents testing.
- Mitigation: use blocker/high/medium/low classification and ship only when blockers are closed.

Effort: Small.
