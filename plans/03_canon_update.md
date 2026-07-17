# 03 — Canon update (three hearts + docs CI)

**Status:** execution plan. Run after plan 02 gate. **Must complete before plan 04.**  
**Depends on:** [`02_alignment_and_kill_list.md`](02_alignment_and_kill_list.md)  
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

1. **Brain / body** — Grok understands every chat/voice turn; backend executes capabilities; no second understanding layer of regex/overlap/embeddings.
2. **Personality** — Grok’s native voice; Clarity does not ship a long persona prompt.
3. **Token budget** — default model input target ≤ ~1k tokens; heavy data via on-demand fetch capabilities.
4. **Capability catalog** — short names of what the body can do; Auto Suggestions (Off/Text/Card) gates **offers after** understanding.
5. **Person memory** — person cards hold identity + rolling confirmed **state** and notes; Connections and Shared history are Saved Memory; chat search for long detail; no silent graph.
6. **Finance** — assistant does what the user can do in-app; insights via fetch; no invented world actions (email, etc.).
7. Keep existing Truth, voice-primary, Open Threads vs Goals vs Chat History distinctions.

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
- Always-on dump of full Knows or full finance into every turn.
- Claim email/SMS/external actions or saves without body apply.
- Add new planning docs under `docs/` outside the three hearts.
- Archive competing plans instead of deleting them when retiring process docs.
- Invent Connections / Shared history or use them in answers before Knows-visible.

### When working on the assistant

- One pipeline, many capability handlers.
- Prefer deleting mismatching brain code over compatibility shims (see plan 04).
- Follow `plans/01–05` in order for the brain redesign.

Retain existing social / confirm / voice parity rules; rephrase so they sit under body capabilities, not detectors.

## 4. PROJECT_STRUCTURE.md — required edits

1. **Replace assistant production path diagram** with the simple target pipeline from [`plans/README.md`](README.md).
2. **Document `plans/`** — only execution plans; order 01→05; not canon product law.
3. **Docs policy** — `docs/` root = three files only; **no** `docs/archive/` allowance after this plan (delete archive in plan 04).
4. **Brain vs body file map**
   - Body: durable write, open_thread_service, clarity control, recall engine, settings, truth.
   - Deleted/forbidden as understanding: intent routers, open_thread eligibility/overlap offer detectors, memory/goal short-circuit detectors (point at plan 02 kill list).
5. **Token / prompt rules** — capability names + thin state; fetch packs; ≤1k default target.
6. Update “Where to look first” for assistant questions → Grok pipeline + `plans/` + body modules.
7. Keep file-size limits and features/ vs rex/ separation.

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

- [ ] Edit MASTER_PLAN per §2
- [ ] Edit CLARITY_RULES per §3
- [ ] Edit PROJECT_STRUCTURE per §4
- [ ] Edit `verify_docs_canon.sh` per §5
- [ ] Sync `.cursor/rules` mirrors if present

### Phase B — Consistency pass

- [ ] No leftover “heuristic intent owns the turn” language in the three hearts
- [ ] `plans/` referenced as only execution plans
- [ ] Personality = Grok native; no persona prompt requirement

### Phase C — Manual gate

- [ ] Human review of the three hearts
- [ ] `scripts/verify_docs_canon.sh` passes on the PR
- [ ] Merge canon **before** starting plan 04 deletion

## 8. Explicit non-goals for 03

- No deletion of `docs/archive/` here (plan 04)
- No deletion of Python short-circuits here (plan 04)
- No new brain implementation (plan 05)
