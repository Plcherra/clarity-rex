# 11 — Post-Launch Refactoring and Nice-to-Haves

**Covers:** God-file freezes/splits, silent catch cleanup, desktop non-targets, experimental flags, archived launch-prep debt, and complexity reduction. **Do not prioritize these over Saturday blockers** in files 01–07 (or product tracks 08–09 when claimed).

**Primary paths:** `PROJECT_STRUCTURE.md` watch list, large `services/rex-api/app/services/*` modules, experimental voice flags

---

## Phase 1 — Freeze oversized files for launch week

### Issue: God-file watch list near 500 lines (L2)

- **Severity:** Low (launch regression risk if touched)
- **Why it matters:** Feature edits in 443–471 line modules invite merge pain and policy violations (>500 lines).
- **Estimated effort:** Small (process) / Large (full splits)
- **Brief fix suggestion:** Freeze feature work in: `plan_intelligence_service.py`, `memory_intent_facts.py`, `plaid_sync_service.py`, `memory_turn_service.py`, `chat_turn_orchestrator.py`, `plan_merge_service.py`, `memory_retrieval_ranker.py`, `memory_intent_service.py`. Split only if a Saturday fix must land there.

---

## Phase 2 — Planned splits (post-launch)

### Issue: Split watch-list modules by responsibility (A57)

- **Severity:** Low
- **Why it matters:** Shipping-phase rule: extract before growing; long-term maintainability.
- **Estimated effort:** Large
- **Brief fix suggestion:** One thin orchestrator (~80–120 lines) + focused modules; move tests with code; keep public behavior unchanged. Start with the file you must touch next.

### Issue: Do not re-grow recently split modules (A58)

- **Severity:** Low
- **Why it matters:** `chat_turn_orchestrator*`, usage tracking split, mobile chat/voice splits, recall modules were already extracted.
- **Estimated effort:** Small (discipline)
- **Brief fix suggestion:** Code review gate: reject PRs that push these back over 400–500 lines.

---

## Phase 3 — Silent catch cleanup

### Issue: Selected silent `except` paths (A59)

- **Severity:** Low–Medium
- **Why it matters:** Hides operational failures; some are acceptable (LLM refine fallback), others should metric.
- **Estimated effort:** Medium
- **Brief fix suggestion:** Audit and classify:
  - `durable_write_proposal_refiner.py` — OK to return unrefined; add debug log
  - `voice_call_controller_timers.dart` barge-in — log once
  - `chat_controller.dart` pending hydration — fixed in file 01/05
  - `memory_discipline_service.py` / `memory_reference_resolver.py` empty returns — fixed in file 01
  - `BackgroundVoiceService` swallowing `MissingPluginException` — expected on iOS until bridge; log at info

### Issue: No TODO/FIXME/HACK in core rex paths (A60)

- **Severity:** Low (positive)
- **Why it matters:** Unusually clean — protect the standard.
- **Estimated effort:** None
- **Brief fix suggestion:** Keep PR hygiene; do not introduce launch TODOs in production paths.

---

## Phase 4 — Desktop and experimental surfaces

### Issue: Desktop macOS/Windows not a launch target (A61)

- **Severity:** Low
- **Why it matters:** No Plaid, no voice — claiming desktop support misleads.
- **Estimated effort:** Small
- **Brief fix suggestion:** Keep capability gates; exclude from launch marketing and TestFlight/Play messaging.

### Issue: Experimental native iOS voice bridge must stay off (A42 — also in 06)

- **Severity:** Low
- **Why it matters:** Second pipeline violates single-brain rule.
- **Estimated effort:** Small
- **Brief fix suggestion:** Leave experimental flags false; delete or archive dead bridge code post-launch if unused.

### Issue: Legacy brain modules already deleted — do not resurrect (A62)

- **Severity:** Low
- **Why it matters:** Debug only in `SimpleRexBrain` / `ChatTurnOrchestrator` / `ChatService`.
- **Estimated effort:** None
- **Brief fix suggestion:** Reject PRs that reintroduce `rex_brain*` experiment modules.

---

## Phase 5 — Product surface debt (known incomplete)

### Issue: Single pending_action slot for plan + delete (A28 — also in 04 / file 08 Phase 3)

- **Severity:** Medium
- **Why it matters:** Concurrent confirms can collide; file import needs a queue.
- **Estimated effort:** Large
- **Brief fix suggestion:** Post-launch queue or multi-pending model — prefer implementing via file 08 Phase 3 when claiming multi-fact import.

### Issue: Accountability drill-down routes unused on mobile (A63)

- **Severity:** Low
- **Why it matters:** `/signals`, `/rule-risks`, `/plan-risks`, `/patterns` remain backend-only.
- **Estimated effort:** Large
- **Brief fix suggestion:** Defer; Goals overview is enough for MVP.

### Issue: Entity events + memory corrections UI missing (A64)

- **Severity:** Low
- **Why it matters:** Backend CRUD exists; Knows MVP correctly hides Corrections tab.
- **Estimated effort:** Large
- **Brief fix suggestion:** Defer per PROJECT_STRUCTURE; do not promise in privacy/marketing (file 10).

### Issue: Plan update / entity-event conversational routes thin (A65)

- **Severity:** Medium
- **Why it matters:** Create/milestone confirm is stronger than update/event paths.
- **Estimated effort:** Large
- **Brief fix suggestion:** Post-launch plan discipline completeness sprint — not Saturday.

---

## Phase 6 — Archived launch-prep hygiene

### Issue: Older launch-prep docs still unchecked / stale (A66)

- **Severity:** Low
- **Why it matters:** Suggests incomplete pre-launch cleanup; confuses which checklist is authoritative.
- **Estimated effort:** Small
- **Brief fix suggestion:** Treat **this `saturday-audit/` pack** as the active tracker; mark older `launch-prep/0x-*.md` items superseded or complete them deliberately.

### Issue: MFA production config verification (A67)

- **Severity:** Medium
- **Why it matters:** MFA UI exists; Supabase MFA must be enabled/configured in prod or the flow dead-ends.
- **Estimated effort:** Small (ops)
- **Brief fix suggestion:** Verify Supabase Auth MFA settings for prod project; smoke enroll + challenge once.

---

## Phase 7 — Cost and abuse hardening (non-blocking)

### Issue: Unbounded chat / context payloads (M4 — also in 03)

- **Severity:** Medium
- **Why it matters:** Cost abuse after launch as user count grows.
- **Estimated effort:** Small
- **Brief fix suggestion:** Implement max_length caps if not done in file 04 before traffic grows.

### Issue: No adaptive voice bitrate / low-power mode (A40 — also in 06)

- **Severity:** Low–Medium
- **Why it matters:** Battery and STT/TTS cost on long sessions.
- **Estimated effort:** Large
- **Brief fix suggestion:** Post-launch voice efficiency sprint.
