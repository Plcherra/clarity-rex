# Clarity Next Steps - Phased Execution Plan

**Current Canon:** Only 3 documents (`MASTER_PLAN.md`, `CLARITY_RULES.md`, `PROJECT_STRUCTURE.md`)

**This file:** Working execution tracker only — not canon. Delete or move to `docs/archive/` when all phases are Done.

**Background:** Project Alignment Audit (July 2026) found canon docs and Cursor rules are aligned, but code and user-facing copy still violate them — mainly retired **commitments**, mixed **Open Thread** labeling, and **Rex Brain** naming that sounds like a separate system.

We execute **phase by phase**, not all at once.

---

## Phase 0 - Immediate P0 Fixes (Do this first)

**Goal:** Stop user-visible and assistant-prompt truth violations. Highest impact; closes the gap between canon and what users/assistant actually see.

**Canon violated today:**
- `CLARITY_RULES.md` §3 — commitments retired; Open Threads replace companion follow-up
- `PROJECT_STRUCTURE.md` §7 Legacy — commitments *"migration only — not in Knows, prompts, or new UI"*

**Status:** Done

### [x] 0.1 Remove commitment create/edit from Knows UI

| | |
|---|---|
| **Why** | Open Threads belong on Goals tab, not Knows. Commitments are not product surface. |
| **Files** | `apps/mobile/lib/rex/memory/presentation/pages/memory_page.dart` — remove `MemoryCreateKind.commitment` case, `_editCommitment`, commitment list/filter wiring |
| | `apps/mobile/lib/rex/memory/presentation/widgets/memory_create_sheets.dart` — remove commitment from create-kind picker |
| | `apps/mobile/lib/rex/memory/presentation/widgets/memory_page_filters.dart` — remove commitment filter paths if only used for Knows |
| | `apps/mobile/lib/rex/memory/application/memory_action_controller.dart` — remove or gate `createCommitment` / `updateCommitment` if only called from Knows |
| **Do not** | Remove Open Threads from Goals tab or `/open-threads` API |
| **Done when** | Knows create sheet has no commitment option; no commitment tiles editable from Knows |

### [x] 0.2 Remove standalone commitment references from prompt context

| | |
|---|---|
| **Why** | Assistant must not treat legacy commitments as active product knowledge in prompts. |
| **Files** | `services/rex-api/app/services/prompt_structured_context.py` — stop emitting standalone `commitment/` lines; keep plan-linked milestone context only if still required for goal hierarchy |
| | `services/rex-api/app/services/prompt_inventory_context.py` — remove commitment counts and `- Commitment:` inventory lines |
| **Related (review, may defer to Phase 3)** | `services/rex-api/app/routes/accountability_overview_builder.py` still returns `open_commitments` (plan-linked only) |
| **Do not** | Remove Open Threads from `prompt_open_threads_context.py` |
| **Done when** | Prompt assembly tests pass; structured/inventory prompt blocks contain no standalone commitment lines |

### [x] 0.3 Fix Open Threads l10n (commitment → open thread)

| | |
|---|---|
| **Why** | Goals tab already uses Open Threads backend; UI strings still say "commitment" in add/edit/archive flows. |
| **Files** | `apps/mobile/lib/l10n/app_en.arb` — fix inconsistent keys (section title already "Open Threads"; add/edit/archive still say commitment) |
| | Regenerate: `app_localizations_en.dart`, `app_localizations.dart` |
| | `apps/mobile/lib/rex/accountability/presentation/pages/accountability_page.dart` — uses keys like `accountabilityAddCommitmentTitle`, `accountabilityCommitmentSaved` (update keys or string values) |
| **Example fixes** | `accountabilityAddCommitmentTitle` → "Add open thread"; `accountabilityCommitmentSaved` → "Open thread saved"; `accountabilityArchiveCommitmentTitle` → archive open thread |
| **Do not** | Rename `lib/rex/` module folder or Rex personality strings ("Rex is ready") |
| **Done when** | Goals tab Open Threads section: all user-visible strings say "open thread", not "commitment" |

---

## Phase 1 - Documentation & README Cleanup

**Goal:** User-facing docs match canon. No marketing or setup docs describe commitments or Rex Brain as separate product features.

**Status:** Done

### [x] 1.1 Update root README

| | |
|---|---|
| **File** | `README.md` |
| **Changes** | Line ~67: "Goals & commitments" → "Goals & Open Threads" |
| | Line ~141: "Rex Brain" in services blurb → "assistant backend (`services/rex-api`)" |
| | Keep "Rex chat/voice" as assistant personality naming (acceptable per audit) |
| **Done when** | Docs section lists 3 canon files; no product-feature mention of commitments or Rex Brain |

### [x] 1.2 Update Rex API README

| | |
|---|---|
| **File** | `services/rex-api/README.md` |
| **Changes** | Opening: frame as assistant backend **inside Clarity**, not a separate product |
| | Line ~9: move `commitments` to **legacy/migration-only** (not normal assistant data) |
| | Keep links to `CLARITY_RULES.md` and `PROJECT_STRUCTURE.md` |
| **Done when** | README data model list matches PROJECT_STRUCTURE §7 Legacy |

### [x] 1.3 Sweep remaining user-facing "commitments"

| | |
|---|---|
| **Files to check** | `apps/mobile/README.md`, `apps/mobile/lib/l10n/app_en.arb` (memory/Knows strings after Phase 0), gallery copy in README |
| **Done when** | Grep for user-facing "commitment" only hits legacy code comments, migration paths, or plan-linked backend fields — not product UX |

---

## Phase 2 - Naming & Code Cleanup

**Goal:** Reduce developer confusion. One unified assistant pipeline aligned with canon — not an "experimental brain", "launch brain", or before/after version.

**Unified assistant:** Clarity has one production path: `ChatService` → `ChatTurnOrchestrator` → `SimpleRexBrain`. Rex is the assistant personality inside Clarity, not a separate subsystem.

**Status:** Done

### [x] 2.1 Rename production-facing "Rex Brain" strings

| | |
|---|---|
| **Why** | `/ready` and voice config strings sound like a subsystem brand; canon says Rex is assistant personality inside Clarity. |
| **Files** | `services/rex-api/app/main.py` — `/ready` message: prefer "production assistant pipeline (SimpleRexBrain)" not "Simple Rex Brain is the production launch brain" |
| | `services/rex-api/app/services/voice_stream_config.py` — "Rex Brain truth rules" → "assistant truth rules" or "same rules as chat" |
| | `services/rex-api/app/services/chat_service.py` — comments referencing "Rex Brain surface" |
| | `services/rex-api/app/services/transcript_normalizer.py` — comment "before Rex Brain processing" |
| **Do not** | Rename `SimpleRexBrain` class or `lib/rex/` paths in this phase (large refactor) |
| **Done when** | Operator-facing strings and production comments avoid "Rex Brain" as product noun |

### [x] 2.2 Delete unused legacy `rex_brain*` modules

| | |
|---|---|
| **Why** | 13 legacy modules marked `NON-PRODUCTION FOR LAUNCH` sit beside production code; grep is misleading. They are not wired into the current assistant pipeline. |
| **Approach** | Delete unused `rex_brain*` service modules and their tests. Extract small production helpers (e.g. proactive monitoring terms) before delete. |
| **Files** | `rex_brain.py`, `rex_brain_chat_service.py`, `rex_brain_*.py` (13 total), `tests/test_rex_brain*.py`, legacy cleanup scripts |
| **Keep** | `simple_rex_brain.py`, `rex_channel.py`, trimmed `rex_observability.py` (`MemoryOperationObserver` only) |
| **Done when** | No legacy `rex_brain*` modules remain; production imports only the unified pipeline |

### 2.3 Prune dead commitment UI (if confirmed unused)

| | |
|---|---|
| **Files** | `apps/mobile/lib/rex/accountability/presentation/pages/accountability_page_tiles.dart` — `_CommitmentTile` (not rendered in current Goals layout) |
| | `accountability_controller.dart` — `createCommitment` / `updateCommitment` if no callers remain |
| **Done when** | No dead commitment widgets or controller methods without callers |

---

## Phase 3 - Guardrails & Legacy API

**Goal:** Prevent regression. Finish commitment retirement at API layer.

**Status:** Not started

### 3.1 Deprecate `/commitments` for new product use

| | |
|---|---|
| **Files** | `services/rex-api/app/routes/commitments.py`, `main.py` router registration |
| **Approach** | Keep read/migration routes; block or remove mobile create/update after Phase 0–1 |
| | `structured_memory_repository.py` — commitment CRUD stays for migration |
| **Done when** | No mobile or prompt path creates standalone commitments; API documented as legacy |

### 3.2 Prevent future doc sprawl

| | |
|---|---|
| **Approach** | CI check or pre-commit: fail if new files appear under `docs/` outside the 3 canon files (allow `docs/archive/` with non-canon header) |
| | Ensure git tracks only canon + this tracker; do not resurrect `docs/brain/` without archival label |
| **Done when** | Automated check exists; `docs/` stays at 3 canon files (+ this file until deleted) |

---

## Execution rules

- Always keep this file short and up-to-date.
- Mark completed items as **Done** (and sub-items `[x]`).
- Only work on **one phase at a time** unless explicitly told otherwise.
- Never create new documents outside the 3 canon files (this tracker is the sole exception).
- After each phase: run relevant tests (`test_prompt_service.py`, accountability/mobile tests, backend open-thread tests).

## Phase checklist

| Phase | Summary | Status |
| --- | --- | --- |
| 0 | Knows + prompts + Open Thread l10n | Done |
| 1 | READMEs + commitment copy sweep | Done |
| 2 | Rex Brain naming + legacy module cleanup | Done |
| 3 | `/commitments` deprecation + doc sprawl guard | Not started |
