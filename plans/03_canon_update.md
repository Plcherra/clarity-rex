# 03 — Canon update (three hearts + docs CI)

**Status:** Phases A–C complete (2026-07-17). Canon reviewed and merged; proceed to plan 04.  
**Depends on:** [`02_alignment_and_kill_list.md`](02_alignment_and_kill_list.md) (gate accepted)  
**Next:** [`04_aggressive_deletion.md`](04_aggressive_deletion.md)

## 1. Purpose

Update the only product/engineering law so agents cannot deviate back into heuristic brains or parallel plan docs.

Canon root remains exactly:

- [`docs/MASTER_PLAN.md`](../docs/MASTER_PLAN.md)
- [`docs/CLARITY_RULES.md`](../docs/CLARITY_RULES.md)
- [`docs/PROJECT_STRUCTURE.md`](../docs/PROJECT_STRUCTURE.md)

Execution plans live only under [`plans/`](../plans/).

## 2. MASTER_PLAN.md — required edits

Add or revise sections so vision states:

1. **Brain / body** — Grok is the **LLM brain** every chat/voice turn; backend executes capabilities; no second understanding layer of regex/overlap/embeddings.
2. **Speech** — **Google TTS** for spoken replies; Grok is not the TTS engine. No long persona prompt.
3. **Token budget** — **base** turn aims **&lt; ~1k** input; may grow when tools/fetch/heavy context are needed (situation-dependent). Do not always-on dump finance/Knows.
4. **Capability catalog** — short names of what the body can do (incl. milestones + person-card net); Auto Suggestions (Off/Text/Card) gates **offers after** understanding. No reply-length setting.
5. **Person memory** — person cards + state + notes; Connections, Shared history, and later named social groups are Saved Memory; chat search for long detail; no silent graph. Duplicates are **deleted**, not archived.
6. **Finance** — assistant does what the user can do in-app (Plaid sync, categorize, budgets…); insights via fetch; no invented world actions (email, etc.).
7. Keep existing Truth, voice-primary, Open Threads vs Goals vs Chat History distinctions.
8. Product one-liner intent from [`plans/README.md`](README.md) (confirm saves, dark-first, EN+ES now, more languages over time).

Do not turn MASTER_PLAN into an API dump — product vision only.

## 3. CLARITY_RULES.md — required edits

### Always

- Use Grok as the understanding brain for chat and voice turns.
- Apply Auto Suggestions only after structured intent/action from the brain.
- Keep capability catalog aligned with real app features.
- Keep default turn context thin; fetch finance/person/recall when needed.
- Enforce Truth Rule on every reply.

### Never

- Build or keep heuristic/regex/overlap/embedding **understanding** that short-circuits Grok.
- Put personality essays in the system prompt to “create” Rex.
- Force reply length (concise/balanced/detailed) that overrides natural Grok answers.
- Always-on dump of full Knows or full finance into every base turn.
- Claim email/SMS/external actions or saves without body apply.
- Add new planning docs under `docs/` outside the three hearts.
- Archive competing plans or duplicate user data instead of **deleting** them when retiring.
- Invent Connections / Shared history / groups or use them in answers before Knows-visible.

### When working on the assistant

- One pipeline, many capability handlers.
- Prefer deleting mismatching brain code over compatibility shims (see plan 04).
- Follow `plans/01–05` in order for the brain redesign.

Retain existing social / confirm / voice parity rules; rephrase so they sit under body capabilities, not detectors.

## 4. PROJECT_STRUCTURE.md — required edits

1. **Replace assistant production path diagram** with the simple target pipeline from [`plans/README.md`](README.md). Prefer a short mermaid (or equivalent) — not a UML suite.
2. **Document `plans/`** — only execution plans; order 01→05; not canon product law.
3. **Docs policy** — `docs/` root = three files only; **no** `docs/archive/` allowance after this plan (delete archive in plan 04).
4. **Brain vs body file map**
   - Body: durable write, open_thread_service, clarity control, recall engine, settings, truth.
   - Deleted/forbidden as understanding: intent routers, open_thread eligibility/overlap offer detectors, memory/goal short-circuit detectors (point at plan 02 kill list).
5. **Token / prompt rules** — capability names + thin state; base aim &lt;~1k; fetch packs may add tokens when needed.
6. **Environments (light — need)** — short matrix only:

   | Env | API | Secrets | Notes |
   |-----|-----|---------|--------|
   | Local | localhost rex-api | `services/rex-api/.env`, mobile `.env` | Dev |
   | Prod VPS | `/opt/clarity/current` | `/opt/clarity/shared/rex-api.env` | Canonical prod; Auto Suggestions from **profile**, not env override that wipes Off |

   Staging / multi-region = out of scope until after plan 05 unless already required.
7. **CI** — note `.github/workflows/ci.yml` (Flutter, pytest, docs canon). CD auto-deploy = nice later; restart today via `scripts/vps_restart_rex_api.sh`.
8. Update “Where to look first” for assistant questions → Grok pipeline + `plans/` + body modules.
9. Keep file-size limits and features/ vs rex/ separation.

## 5. `scripts/verify_docs_canon.sh` — required edits

Today allows new files under `docs/archive/*`. Change to:

- Allowed under `docs/` **only**:
  - `docs/MASTER_PLAN.md`
  - `docs/CLARITY_RULES.md`
  - `docs/PROJECT_STRUCTURE.md`
- **Remove** the `docs/archive/*` exception.
- Fail CI if any other path is added under `docs/`.

After plan 04 deletes `docs/archive/`, the tree must stay clean.

## 6. Cursor / agent rules sync

If workspace rules mirror the three hearts (`.cursor/rules/*`), update them in the **same PR as canon** so agents do not keep teaching short-circuit brains. Do not invent a fourth canon doc.

## 7. Phases

### Phase A — Draft canon diffs

- [x] Edit MASTER_PLAN per §2
- [x] Edit CLARITY_RULES per §3
- [x] Edit PROJECT_STRUCTURE per §4
- [x] Edit `verify_docs_canon.sh` per §5
- [x] Sync `.cursor/rules` mirrors if present

### Phase B — Consistency pass

- [x] No leftover “heuristic intent owns the turn” language in the three hearts
- [x] `plans/` referenced as only execution plans
- [x] Grok = LLM; Google TTS = speech; no persona prompt; no reply-length setting in canon
- [x] Env matrix present; no claim that staging/CD is required for cutover
- [x] Duplicates → delete; social groups with person-card net

### Phase C — Manual gate

- [x] Human review of the three hearts *(accepted 2026-07-17)*
- [x] `scripts/verify_docs_canon.sh` passes on the PR (CI docs job)
- [x] Merge canon **before** starting plan 04 deletion

## 8. Explicit non-goals for 03

- No deletion of `docs/archive/` here (plan 04)
- No deletion of Python short-circuits here (plan 04)
- No new brain implementation (plan 05)
- No new staging environment or CD pipeline in this plan
