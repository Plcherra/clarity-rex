# 08 — File Import → Memory, Goals, and Open Threads

**Covers:** Turn chat file attachments into durable Knows / Goals / Open Threads proposals through the existing confirm stack. Today uploads only feed Grok Q&A (~15–20% of this MVP). This track finishes extraction → propose → confirm → visible records.

**Why this order (not plan 2):** Keep Saturday blockers first (truth, observability, security, reliability, Plaid, voice). File import is a **post-truth product capability** that reuses the confirm stack already shipping in 01 / person-confirm / text-mode work. Place it **after Voice (07)** and **before Spanish (09)** so new strings can land in the i18n pass, and **before Privacy (10)** so subprocessors/retention copy can mention file-derived saves. Do **not** put it ahead of Data Integrity — wrong “saved from your file” claims are worse than missing import.

**Primary paths:** `file_service.py`, new `file_extraction_service.py` (or equivalent), `chat_turn_orchestrator*` / short-circuit, `durable_write_service.py`, `conversation_pending_action.py`, `chat_attachment.dart`, `chat_page.dart` / composer attach, confirm strip / person card, Knows + Goals refresh

**Canon:** `CLARITY_RULES.md` — never claim saved/remembered/done unless the user can see and control it in Knows / Goals / Open Threads. Chat history ≠ Saved Memory.

---

## Locked product rules

- **One brain:** Same `ChatService` → `ChatTurnOrchestrator` → `DurableWriteService` / Open Threads path as typed chat. No second importer brain, no silent DB writes from files.
- **Reuse off / text / card:** `AssistantProposalSettings.mode` gates proposals exactly as for typed saves.
  - **Off:** no auto proposals from files (manual Knows/Goals unchanged).
  - **Text:** chat-only confirm (“Say yes…”); **never** surface `write_proposals` cards.
  - **Card:** existing confirm UIs (person card when person-shaped; generic cards for flat memory / plans / threads).
- **Truth:** Rex may say “I found N things — confirm to save” only when proposals are pending. Never “I saved it from your file” until apply returns and Knows/Goals show the item.
- **Explicit import intent:** Do not auto-dump every attachment into proposals. User must signal import (e.g. “save this”, “remember what’s in this file”, “turn this into Knows/Goals”) **or** a clear product CTA after attach. Plain “what’s in this PDF?” stays Q&A-only.
- **User-scoped:** All extraction and writes scoped to the authenticated user; attachment text must not leak across users.
- **File size / type:** Respect existing `FileService` / mobile attachment limits (txt/md/csv 2MB, pdf 10MB, images 5MB). Phase 1 focuses on **txt/md**; expand carefully.

```text
User attaches file + import intent
 → FileService.read_attachment (existing)
 → FileExtractionService → candidate facts / people / goals / threads
 → map each candidate → DurableWriteProposal (or Open Thread consent)
 → queue: one active pending write at a time (Phase 3)
 → off / text / card confirm (existing)
 → DurableWriteApplier / OpenThreadService
 → Knows / Goals refresh — only then claim success
```

---

## Current state (baseline)

### Works today

- Chat attach: txt, md, csv, pdf, jpg/png/webp (`chat_attachment.dart`, `FileService`).
- Text/PDF extraction into prompt context; images multimodal to Grok.
- Single-turn durable propose/confirm for **typed** messages (person card, text/card/off).

### Gaps

- No file-aware extraction → `write_proposals`.
- Propose handlers key off typed message, not attachment body.
- **One** `pending_action` per conversation — supersedes prior pending save (blocks “12 facts from this dump”).
- No OCR; scanned PDFs/images are Q&A-only.
- Chat CSV ≠ finance CSV importer (`AccountStatementImportService`).
- Repo root dumps (`context memory conversation.txt`, `grok conversation history.txt`) are **not** product importers — only fixtures for manual QA.
- Voice has no file upload (out of scope for MVP of this file).

---

## Phase 1 — FileExtractionService (txt/md first)

### Issue: No structured extraction from attachments (A80)

- **Severity:** High (blocks the feature)
- **Why it matters:** Attachment text only answers questions; nothing becomes Knows/Goals/Threads.
- **Estimated effort:** Medium
- **Brief fix suggestion:** Add focused `FileExtractionService` (keep `file_service.py` under size limits). Input: cleaned attachment text + optional user hint. Output: capped list of candidates with `kind` (`memory` / `person` / `plan` / `open_thread`), title/body fields, confidence, and source span. Start with **txt/md** only. Prefer deterministic + light LLM structured extract over free-form Grok chat. Cap candidates (e.g. ≤10–20) to protect cost and UX.

### Issue: Extraction must not invent durable truth (A81)

- **Severity:** Critical (truth)
- **Why it matters:** Hallucinated “facts from the file” that never appear in the file violate honesty.
- **Estimated effort:** Medium
- **Brief fix suggestion:** Require each candidate to cite a short source excerpt; drop candidates without grounding. Prompt labels: “Candidates from uploaded file — not saved until confirmed.” Truth policy: never claim applied until confirm path succeeds.

### Issue: Respect proposal mode before any propose (A82)

- **Severity:** High
- **Why it matters:** Text mode must not leak cards; off must not auto-propose.
- **Estimated effort:** Small
- **Brief fix suggestion:** Gate through existing `allows_kind` / `DurableWriteService._propose` text-vs-card behavior already used for typed saves.

---

## Phase 2 — Wire import intent into the turn pipeline

### Issue: Attachment + “save this” still only Q&A (A83)

- **Severity:** High
- **Why it matters:** Users already attach files and ask to remember; product does nothing durable.
- **Estimated effort:** Medium
- **Brief fix suggestion:** Detect **import intent** when `attachment_context` is present and message matches save/remember/import patterns (reuse / extend `rex_intent` / memory-intent “save this” family — do not hardcode one user’s dump). Short-circuit or pre-brain step: run `FileExtractionService` → propose first candidate (or summarize N found and propose first). Keep non-import attachment turns on the existing Q&A path.

### Issue: Orchestrator / short-circuit file growth (A84)

- **Severity:** Medium (shipping-phase file size)
- **Why it matters:** `chat_turn_orchestrator*` is on the watch list; stuffing extraction inline will re-grow it.
- **Estimated effort:** Small–Medium
- **Brief fix suggestion:** Thin hook in orchestrator/short-circuit; all parsing/mapping in `file_extraction_*` modules. Stop before 400–500 lines on orchestrator files.

### Issue: Person-shaped candidates use person confirm path (A85)

- **Severity:** Medium
- **Why it matters:** People from files should get the same ≥2-field / merge / off-text-card behavior as typed “my mom…”.
- **Estimated effort:** Medium
- **Brief fix suggestion:** Map person candidates through existing `person_confirm_proposal` / `person_card` payload; do not invent a second person UI.

---

## Phase 3 — Multi-proposal queue (one active pending)

### Issue: Single pending_action supersedes prior save (A28 / A86)

- **Severity:** High for file import (Medium elsewhere)
- **Why it matters:** File dumps produce many candidates; today’s store replaces the earlier pending write (“I replaced your earlier pending save…”).
- **Estimated effort:** Large
- **Brief fix suggestion:** Introduce a **user-scoped proposal queue** for file-import (and reusable later): store remaining candidates; keep **one** active `pending_action` / client card (or text confirm) at a time. On confirm or reject, advance to next. Reject-all / cancel-import clears the queue. Do not silently apply the rest. Prefer general queue design over a file-only hack.

### Issue: Progress honesty in chat (A87)

- **Severity:** Medium
- **Why it matters:** User must know how many left and that nothing is saved until confirmed.
- **Estimated effort:** Small
- **Brief fix suggestion:** Copy like “1 of 8 — confirm to save to Knows” (card) or equivalent text-mode prompt. After last item: “That’s all from this file.” Never imply the whole batch is saved after one yes.

---

## Phase 4 — Mobile confirm UX for import batches

### Issue: Composer/attach UX does not signal import vs Q&A (A88)

- **Severity:** Medium
- **Why it matters:** Ambiguous attach + send feels like “it should have saved.”
- **Estimated effort:** Small–Medium
- **Brief fix suggestion:** Keep attach as today; rely on import-intent phrases for MVP, **or** add a light “Save to Knows…” affordance after attach. Prefer copy/CTA over a second upload pipeline. EN/ES via ARB when strings land (coordinate with file 09).

### Issue: Sequential confirm must refresh Knows/Goals per apply (A89)

- **Severity:** High (truth)
- **Why it matters:** Batch UX must still refresh after each successful apply so items appear immediately.
- **Estimated effort:** Small
- **Brief fix suggestion:** Reuse existing confirm → `write_confirmation` → `memoryProvider` / `accountabilityProvider` refresh. No deferred “refresh once at end” that hides partial success.

### Issue: Dismiss / reject mid-batch (A90)

- **Severity:** Medium
- **Why it matters:** User may want to skip one fact or abort the import.
- **Estimated effort:** Small
- **Brief fix suggestion:** Reject = skip this candidate, advance queue. Explicit cancel = clear queue + honest “Stopped — nothing else will be saved.”

---

## Phase 5 — PDF text path (no OCR yet)

### Issue: PDF text extract exists but no import mapping (A91)

- **Severity:** Medium
- **Why it matters:** Many user dumps are PDF; `FileService` already truncates PDF text for prompts.
- **Estimated effort:** Medium
- **Brief fix suggestion:** After txt/md is solid, feed PDF `attachment.text` into the same `FileExtractionService` with the existing char cap. Document that scanned/image-only PDFs will yield empty/poor extraction until OCR (Phase 6).

### Issue: Chat CSV must not become finance import (A92)

- **Severity:** High (product clarity)
- **Why it matters:** Mixing chat CSV with `AccountStatementImportService` corrupts money data or confuses users.
- **Estimated effort:** Small (policy + copy)
- **Brief fix suggestion:** Chat CSV stays memory/Q&A candidates only (or “not supported for Knows import” in Phase 1). Finance CSV remains Accounts / statement import only. Never auto-create transactions from chat attach.

---

## Phase 6 — Later: OCR and voice attach (explicitly deferred)

### Issue: Images / scanned PDFs need OCR (A93)

- **Severity:** Low for Saturday; Medium for full vision
- **Why it matters:** Photos of notes are common; multimodal Q&A ≠ durable extract.
- **Estimated effort:** Large
- **Brief fix suggestion:** Post-MVP: OCR (or structured vision extract) → same candidate → queue → confirm path. Do not claim OCR in marketing until shipped.

### Issue: Voice has no file upload (A94)

- **Severity:** Low (defer)
- **Why it matters:** Voice is primary UX, but file import is chat-led for MVP.
- **Estimated effort:** Medium
- **Brief fix suggestion:** Optional later: attach-from-chat then continue in voice, or voice “save that file we just discussed” using last attachment id. Same confirm stack; no second pipeline.

---

## Phase 7 — Verify

### Issue: End-to-end import smoke (A95)

- **Severity:** High (gate for claiming the feature)
- **Why it matters:** Without E2E, easy to overclaim “import your notes.”
- **Estimated effort:** Medium
- **Brief fix suggestion:** Tests + manual:
  1. Attach small txt/md with 2–3 clear facts + “save what’s in this file.”
  2. **Card:** sequential cards; each confirm → item in Knows/Goals; reject skips.
  3. **Text:** no cards; yes/no advances queue; items appear after yes.
  4. **Off:** no proposals; Q&A still works.
  5. Person candidate → person card / text 2-field rules.
  6. Open thread candidate → consent rules (max 5).
  7. Cancel mid-batch → queue cleared; no silent applies.
  8. Non-import “summarize this file” → no proposals.
  9. Backend unit tests for extractor grounding + queue advance; Flutter parser/confirm regressions.

### Issue: Abuse / cost caps (A96)

- **Severity:** Medium
- **Why it matters:** Large dumps + LLM extract = cost and latency spikes.
- **Estimated effort:** Small
- **Brief fix suggestion:** Enforce attachment size limits; cap candidates; optional rate limit on import-intent turns; never send full multi-MB dumps unboundedly to Grok for extract.

---

## Out of scope (do not pull into this file)

- Finance CSV / Plaid / transaction categorization (file 06)
- Birthday Event one-time DB backfill (already shipped separately)
- Knows UI density / Goals-out-of-Knows (file 02)
- Spanish FTUE / marketing copy beyond new import strings (file 09)
- Privacy policy subprocessors rewrite (file 10) — only ensure this feature doesn’t invent silent retention
- God-file cleanup unrelated to extraction modules (file 11)
- Importing repo fixture files as a product feature
- Desktop / web parity for attach-import

---

## Suggested implementation order (when executing)

1. Phase 1 extractor (txt/md) + grounding + mode gate  
2. Phase 2 import-intent short-circuit → first proposal  
3. Phase 3 queue (required before claiming multi-fact import)  
4. Phase 4 mobile copy / dismiss / refresh  
5. Phase 5 PDF text  
6. Phase 7 verify  
7. Phase 6 OCR / voice only after MVP claim is honest  

**Saturday ship note:** This file is **not** a must-pass green-light gate. Do not market “import files into Knows” until Phases 1–4 + 7 are done (or explicitly beta-label “Q&A on attachments only”).
