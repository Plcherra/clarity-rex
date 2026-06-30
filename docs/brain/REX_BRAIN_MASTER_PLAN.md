# Rex Brain Master Plan

**Last updated:** 2026-06-30  
**Owner:** Rex Brain / Clarity assistant  
**Related:** [SIMPLE_BRAIN_ARCHITECTURE.md](./SIMPLE_BRAIN_ARCHITECTURE.md) · [MEMORY_TRUST_AUDIT.md](./MEMORY_TRUST_AUDIT.md) · [REX_BRAIN_RULES.md](./REX_BRAIN_RULES.md)

---

## 1. Core Vision (Never Change This)

Rex is Clarity's personal second brain.

- Only visible saved items (Memories + Goals) exist as durable memory.
- Strong read-only chat history search.
- Nothing is saved unless user sees and confirms a proposal card.
- Knows tab must exactly match "What do you know?" response.
- Rex and Clarity are the **same app** — tight integration, shared user data.

---

## 2. Current Problems (List All)

### Trust & data truth

- **Duplicate saved knowledge rows** — org/person duplicates still appear in Knows for some users; cleanup script exists but is not run globally (`cleanup_user_memory_duplicates.py`).
- **Knows vs inventory drift risk** — unified `SavedKnowledgeOverviewService` is in place, but dedupe logic must stay in sync with manual REST CRUD and chat apply paths.
- **Save flow failures after recall** — ~~user asks a recall question, then tries to save something from chat context; proposal card may not appear or confirm may not apply cleanly (orchestrator intent ordering + pending_action supersede edge cases).~~ **Fixed 2026-06-30:** orchestrator runs contextual memory save before stale pending yes/no confirm; goal commands defer to contextual save; stale write_confirmation ids return explicit failure instead of silent LLM fallthrough.
- **Delete confirmation reliability** — delete can still report success while item remains visible in some paths (flat memory vs entity event vs plan/commitment targets).
- **Chat search vs saved memory confusion** — Grok or truth layer can still treat chat excerpts as if they were saved memory when labeling is weak or search status is partial/degraded.
- **Goals tab stale after voice save** — chat refreshes `accountabilityProvider` on apply; voice-only confirm path must mirror chat refresh hooks every time.

### Architecture & complexity

- **Simple Brain Reset added code, did not remove it** — ~+6,213 net lines in `apps/mobile/lib/rex` + `services/rex-api/app/services` since M0 (`94df4e2` → HEAD); "simplified" commit alone was +935 net.
- **Legacy backend files still present** — disabled bypasses, not deleted: `person_memory_materializer.py`, `goal_command_reclassify.py`, `plan_merge_service.py` (447 lines), `memory_discipline_service.py` (501 lines), full `conversational_plan_*` stack alongside `durable_write_*`.
- **Parallel brain paths in docs vs code** — production path is documented as one orchestrator, but many pre-reset services still load and confuse debugging.
- **Three truth paths can still disagree** — Knows overview, Goals `/accountability/overview`, and Rex prompt inventory must stay aligned after every write kind.

### Mobile Flutter structure

- **Hybrid state management** — Riverpod 3 (Rex) + ChangeNotifier + `ListenableBuilder` (finance/auth) + local `setState`; high cognitive load at app boundary.
- **God files violate own 400-line policy** — 14+ files over limit in `rex/` alone, including:
  - `chat_controller.dart` (784)
  - `conversation_list_page.dart` (646)
  - `financial_context_service.dart` (609)
  - `memory_page.dart` (585)
  - `voice_call_controller_streaming.dart` (597)
  - `memory_create_sheets.dart` (518)
  - `memory_read_controller.dart` (489)
  - `memory_action_controller.dart` (471)
  - `ui_dependencies.dart` (819) in `app/`
- **Memory module bloat** — 40 Dart files, no `domain/` layer; CRUD orchestration split across page + two 470–490 line controller parts.
- **Voice UI scattered** — `inline_voice_call_panel.dart` lives under `chat/presentation/` instead of `voice/presentation/`.
- **No client-side saved-knowledge repository** — Knows tab pull-refreshes overview; no shared cache invalidated consistently across chat, voice, and manual CRUD.
- **Rex finance duplication** — `rex/data/financial_context_service.dart` parallels `features/finance/` read model instead of delegating to it.

### Recall & search

- **Weak exact-term search** — numeric/date fragments (e.g. "18" vs "June 18") and exact phrases can miss older factual chats.
- **Ranking favors recent noise** — older factual chats can lose to recent test/noisy conversations.
- **Excerpt assembly drops context** — useful detail in adjacent turns may not appear in recall excerpts.
- **Search failure vs empty results** — degraded/unavailable search must not read as "you never said that."

### Entity-first memory (deferred but bleeding in)

- **Flat memories not merged into Person cards** — name, location, work facts still appear as separate rows for some users.
- **Person cards under-aggregate** — high-confidence related self facts stay scattered.
- **Duplicate person/org cards** — alias and org-suffix normalization incomplete without cleanup + stricter create rules.

### Ops & verification

- **Device testing gap** — many brain changes land without on-device confirm-card + Knows refresh smoke.
- **Backend deploy lag** — trust fixes committed locally may not be live on VPS when manually tested.
- **Documentation sprawl** — 10+ brain docs with overlapping scope; this file is the single active plan going forward.

---

## 3. Target Simple Architecture (Mobile + Backend)

One production path. Delete dead code. Mobile stays thin.

### Backend — one turn flow

```text
User message (chat or voice)
  → ChatTurnOrchestrator
      → pending confirm/reject? → DurableWriteService.apply/reject
      → save intent?            → DurableWriteService.propose → write_proposals
      → recall intent?          → ChatRecallService (read-only, labeled excerpts)
      → inventory intent?       → SavedKnowledgeOverviewService → prompt block
      → else                    → SimpleRexBrain + Grok (no save claims)
  → light truth check → response
```

**Keep (production):**

| Module | Role |
|--------|------|
| `ChatTurnOrchestrator` | Single turn router |
| `DurableWriteService` + `DurableWriteApplier` + `DurableWriteProposal` | All chat/voice durable writes |
| `SavedKnowledgeOverviewService` | Single read model for Knows + "what do you know?" |
| `ChatRecallService` / chat search pipeline | Read-only old chat search |
| `SimpleRexBrain` + `ChatContextService` | Prompt assembly (split, not grow) |
| `conversation_pending_action` | Explicit confirm state |

**Delete or archive (after caller audit):**

- `person_memory_materializer.py` (auto materialize on generic create)
- `goal_command_reclassify.py` (direct memory→goal bypass)
- Redundant `conversational_plan_*` modules if fully folded into `durable_write`
- Experimental `rex_brain_*` stack (already archived — remove from import paths)

**Fold, don't duplicate:**

- `plan_merge_service.py` — only via disclosed merge in proposal text
- `memory_discipline_service.py` — propose only; never silent apply on chat path

### Mobile — thin Rex client

```text
lib/rex/
├── chat/          application (Notifier) | data (API) | domain | presentation
├── memory/        application | domain (models + overview repo) | data | presentation
├── voice/         application | data | domain | presentation  ← move voice UI here
├── goals/         (rename accountability/) — same layers
├── shared/
│   ├── assistant_providers.dart
│   └── financial_context_adapter.dart   → delegates to features/finance
└── presentation/  assistant shell only
```

**Mobile invariants:**

- `write_proposals` → `ClarityActionCardsStrip` → `write_confirmation` (chat + voice)
- Knows tab loads `GET /saved-knowledge/overview` only (via one repository)
- After applied write: refresh `memoryProvider` + `accountabilityProvider`
- No save logic on client beyond confirm/reject API calls
- Finance context: gate before attach; delegate to shared financial read model

### Data truth contract

| Source | What it is | UI / Rex label |
|--------|------------|----------------|
| `/saved-knowledge/overview` | Durable saved knowledge | "What Clarity knows" / saved memory |
| Chat search excerpts | Old messages | "From chat history — not saved memory" |
| `/accountability/overview` | Goals + commitments | Goals tab / goals inventory |
| Financial read model | Plaid/Supabase numbers | Finance context only on finance turns |

---

## 4. Open Issues & Priority Table

| Issue | Priority | Status | Next Action |
|-------|----------|--------|-------------|
| Save proposal fails or disappears after recall turn | **P0** | Fixed | Device verified 2026-06-30. Card-only propose text (no duplicate offer); improved confirm card UX in `clarity_action_cards_strip.dart`. |
| Knows shows duplicates (person/org) | **P0** | Open | Run dedupe script per affected user; harden `SavedKnowledgeOverviewService` dedupe; block duplicate create at REST |
| Delete confirms but item still visible | **P0** | Partial | Trace delete target resolution (LTM vs entity vs event vs plan); require confirmed inactive record before success text |
| Knows not refreshing after voice confirm | **P0** | Open | Mirror chat `_refreshSavedMemoryOverviewIfNeeded` in voice stream writer on applied `write_proposals` |
| Legacy backend modules still loaded | **P1** | Open | Audit callers; delete `person_memory_materializer`, disabled reclassify, unused conversational_plan stubs |
| `chat_controller.dart` god file (784 lines) | **P1** | Open | Split: streaming, financial attach, memory/goals refresh, write-proposal handling |
| `memory_page.dart` + create sheets god UI | **P1** | Open | Move CRUD handlers to application coordinators; split sheets by entity type |
| `chat_context_service.py` god file (~409+ lines) | **P1** | Open | Split fetch vs format vs status; stay under 400 lines |
| Net +6k lines since M0 — no deletion pass | **P1** | Open | Schedule delete-before-add PR: remove dead code paths confirmed by tests |
| Hybrid Riverpod + ChangeNotifier | **P2** | Open | Document as intentional for now; no new ChangeNotifier in Rex; finance migration later |
| Recall misses exact dates/numbers | **P2** | Open | Improve generic query expansion + excerpt window in chat search pipeline (no topic patches) |
| Flat memories not grouped into Person cards | **P2** | Deferred | Post-launch entity-first migration per `REX_BRAIN_POST_LAUNCH.md` |
| `ui_dependencies.dart` (819 lines) | **P2** | Open | Split bindings by feature area |
| `rex/data/financial_context_service.dart` duplicates finance | **P2** | Open | Thin adapter over `features/finance/application/financial_read_model_service.dart` |
| Brain doc sprawl | **P3** | Open | Point all active work here + `SIMPLE_BRAIN_ARCHITECTURE.md`; archive the rest |
| Hybrid semantic + keyword search | **P3** | Deferred | Post-launch per `REX_BRAIN_HYBRID_CHAT_SEARCH.md` |

---

## 5. Guiding Rules

- Less code is better.
- Delete before adding.
- Test on device after every small change.
- No new abstraction layers unless absolutely necessary.

**Also non-negotiable (from project rules):**

- One production brain for chat and voice — no second router, memory system, or recall brain.
- Fix generic retrieval failure classes, not smoke-test topic patches (mom, PC, payroll, etc. belong in tests only).
- Files stop at 400 lines; split before adding behavior.
- Backend confirms before Rex claims success.
- Chat history is never saved memory unless the user explicitly saves via confirm card or Knows form.

---

## 6. Success Metrics

We are done with the current simplification wave when:

1. Recall → save → confirm → Knows refresh works on device (chat and voice). Confirm card is the only save offer UI (no duplicate chat text).
2. Knows tab and "What do you know?" return the same item set for the same user.
3. No duplicate person/org rows for new saves (existing users cleaned).
4. Rex mobile + brain services net line count decreases or holds flat over 4 weeks.
5. Zero production files over 500 lines in Rex brain path.
6. Legacy bypass modules deleted, not just disabled.

---

## 7. Related Docs (read order)

1. **This file** — active plan and priorities
2. [SIMPLE_BRAIN_ARCHITECTURE.md](./SIMPLE_BRAIN_ARCHITECTURE.md) — production path diagram
3. [MEMORY_TRUST_AUDIT.md](./MEMORY_TRUST_AUDIT.md) — write path invariants
4. [REX_BRAIN_POST_LAUNCH.md](./REX_BRAIN_POST_LAUNCH.md) — deferred entity-first + hybrid search
5. Archive folder — historical only; do not implement from archived plans
