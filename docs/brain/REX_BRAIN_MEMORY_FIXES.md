# REX_BRAIN_MEMORY_FIXES.md

## 1. Current Issues Summary

- Old flat memories are not being safely merged into Person entities, so facts like "My name is Pedro Martins", "User lives in Somerville", and explicit work details still appear as separate memory rows.
- Person cards exist, but they do not yet aggregate enough high-confidence related self facts from flat memories.
- Delete confirmation can report success while the saved memory or event remains visible.
- Chat keyword search is weak for exact terms and numeric/date fragments, such as finding "June 18" when searching for "18".
- Rex recall can miss older chat evidence even when the Chats tab can find related conversations manually.

## 2. Non-Negotiable Constraints

- Safety first: no destructive migration and no silent data loss.
- Delete reliability comes first. Do not start aggregation work until delete is backend-confirmed and tested.
- Minimal migration: only high-confidence automatic grouping.
- Person aggregation starts conservatively: name, location, birthday, and explicit work facts only.
- Keep flat memories visible as fallback in all phases.
- Never turn chat history into saved memory unless the user explicitly saves it.
- Delete actions must be backend-confirmed before Rex claims completion.
- Keep keyword search simple, user-scoped, and inspectable.
- Do not create a second memory system or a new Rex Brain path.

## 3. Fix Phases

### Phase 1: Reliable Delete Confirmation

**Goal**

Make saved memory and event deletion fully trustworthy before any aggregation work begins.

**Risk & Rollback**

Delete is the highest-risk action because Rex can falsely claim a durable change happened. Use soft-delete/inactive updates only, keep source records recoverable, and rollback by disabling the direct delete intent path if confirmation is not reliable.

**Key files**

- `services/rex-api/app/services/memory_turn_service.py`
- `services/rex-api/app/services/memory_turn_direct_helpers.py`
- `services/rex-api/app/services/memory_correction_service.py`
- `services/rex-api/app/services/long_term_memory_repository.py`
- `services/rex-api/app/services/structured_memory_repository.py`
- `services/rex-api/tests/test_memory_direct_update_flow.py`
- `services/rex-api/tests/test_chat_simple_memory_flow.py`
- `apps/mobile/lib/rex/memory/**`

**Exact changes**

- Trace the delete flow for confirmed "yes" turns and identify whether it targets flat memory, entity event, entity, goal, or plan-like records.
- Require the backend delete/update call to return a confirmed inactive/deleted record before Rex says "deleted".
- If the target cannot be found, make Rex say it could not find the saved item instead of claiming success.
- If the target is ambiguous, ask which saved item to delete.
- Ensure Knows refreshes after delete confirmation.
- Keep deletion as soft-delete/inactive where the repository already supports that pattern.
- Add a regression test for deleting "User plans to watch it tonight" and verifying it no longer appears in saved memory, Rex recall, or Knows active-only view.

**Verification commands**

```powershell
cd services/rex-api
$env:PYTHONPATH=(Get-Location).Path
pytest tests/test_memory_direct_update_flow.py tests/test_chat_simple_memory_flow.py tests/test_memory_reliability_flow.py
```

```powershell
cd apps/mobile
flutter test test/memory_page_test.dart
```

**Manual verification**

- Save or seed `User plans to watch it tonight.`
- Ask Rex: `Can you delete that tonight plan?`
- Confirm with `Yes`.
- Ask: `Check what Clarity knows.`
- Open Knows with active-only enabled.

**Success criteria**

- "Can you delete that tonight plan?" followed by "Yes" removes or deactivates the exact saved item.
- Rex only says "deleted" after backend confirmation.
- The deleted item no longer appears in "What Clarity knows" or the Knows tab with active-only enabled.
- If delete fails or the target is ambiguous, Rex asks for clarification or reports the failure honestly.
- Flat memories that were not deleted remain visible as fallback.

### Phase 2: High-Confidence Person Aggregation

**Goal**

Let Person cards safely absorb only obvious high-confidence self facts from existing flat memories while keeping flat memories visible as fallback.

**Risk & Rollback**

Aggregation can create wrong Person cards or bad aliases if it is too eager. Start with self facts only: name, location, birthday, and explicit work. Do not deactivate flat memories. Rollback by disabling materialization for new fact kinds while leaving existing flat records untouched.

**Key files**

- `services/rex-api/app/services/person_memory_materializer.py`
- `services/rex-api/app/services/memory_retrieval_service.py`
- `services/rex-api/app/services/prompt_structured_context.py`
- `services/rex-api/app/services/long_term_memory_repository.py`
- `services/rex-api/tests/test_chat_simple_memory_flow.py`
- `services/rex-api/tests/test_memory_retrieval.py`
- `apps/mobile/lib/rex/memory/data/person_memory_model.dart`
- `apps/mobile/lib/rex/memory/presentation/widgets/saved_memory_tiles.dart`

**Exact changes**

- Extend Person materialization only for high-confidence self facts:
  - user's full name -> self Person name
  - user location -> self Person location
  - user birthday -> self Person birthday
  - explicit work/job/company facts -> self Person job/workplace/notes
- Use source memory ids on the Person entity metadata so aggregation is traceable.
- Do not deactivate, delete, or hide flat memories during this phase.
- Prefer the Person card in Rex prompt context when it covers the same source memory.
- Keep unrelated financial/account details out of Person aliases. For example, `Bank of America` must not become an alias for Pedro Martins.
- Do not infer a relationship or person identity from bank names, merchants, payroll text, or vague references.
- Add tests for a self Person card aggregating name, location, birthday, and explicit work details without losing the original flat memories.

**Verification commands**

```powershell
cd services/rex-api
$env:PYTHONPATH=(Get-Location).Path
pytest tests/test_chat_simple_memory_flow.py tests/test_memory_retrieval.py tests/test_memory_profile_recall.py tests/test_prompt_service.py
```

```powershell
cd apps/mobile
flutter test test/memory_page_test.dart
```

**Manual verification**

- Seed or save:
  - `My name is Pedro Martins.`
  - `I live in Somerville.`
  - `My birthday is June 18.`
  - `I work at Bom Dough.`
- Open Knows and inspect the Pedro Martins Person card.
- Ask Rex: `What does Clarity know about me?`
- Confirm the original flat memories still exist as fallback.

**Success criteria**

- Pedro Martins Person card can hold name, relationship/self, location, birthday, job/workplace, and notes.
- Flat memories still exist and remain visible as fallback.
- Rex recall prefers the Person card over duplicate flat facts when source ids match.
- No low-confidence, financial institution, account, merchant, or payroll-only terms become person aliases.
- Aggregation does not start unless Phase 1 delete verification is green.

### Phase 3: Knows Display And Edit Polish

**Goal**

Make the Knows tab show aggregated Person cards clearly without hiding fallback memory truth.

**Risk & Rollback**

UI polish can accidentally hide real saved knowledge. Keep fallback flat memories visible, keep active-only filtering explicit, and rollback by showing flat memory groups exactly as before if Person rendering becomes confusing.

**Key files**

- `apps/mobile/lib/rex/memory/data/person_memory_model.dart`
- `apps/mobile/lib/rex/memory/presentation/widgets/saved_memory_group_list.dart`
- `apps/mobile/lib/rex/memory/presentation/widgets/saved_memory_tiles.dart`
- `apps/mobile/test/memory_page_test.dart`
- `services/rex-api/app/routes/memory.py`
- `services/rex-api/app/routes/entities.py`

**Exact changes**

- Show Person cards first, with clear attributes for location, birthday, job/workplace, notes, and important dates.
- Keep flat memories below the cards as compatibility/fallback records.
- Avoid showing unsafe aliases in the Person card UI.
- Make edit fields match the entity model, but do not require users to clean up automatically generated fields manually.
- Ensure active-only filtering applies consistently to flat memories, entity cards, and entity events.
- Keep delete/edit controls explicit and backend-confirmed.

**Verification commands**

```powershell
cd apps/mobile
flutter test test/memory_page_test.dart test/memory_api_test.dart test/memory_label_test.dart
```

```powershell
cd services/rex-api
$env:PYTHONPATH=(Get-Location).Path
pytest tests/test_structured_memory_routes.py tests/test_entity_service.py tests/test_structured_memory_services.py
```

**Manual verification**

- Open Knows with active-only enabled.
- Confirm People appear first when Person cards exist.
- Confirm Pedro Martins shows clean attributes and no unsafe aliases.
- Confirm flat fallback memories are still visible.
- Toggle active-only and confirm inactive/deleted records do not appear as active knowledge.

**Success criteria**

- Knows shows Pedro Martins as one useful Person card.
- `User lives in Somerville` can appear as fallback, but the Person card also carries the location if high-confidence.
- Bad aliases like bank names do not appear on the Person card.
- Active-only mode hides inactive/deleted memory and events consistently.
- Flat memories remain visible as fallback in all relevant views.

### Phase 4: Basic Chat Keyword Search Repair

**Goal**

Make the Chats tab and backend recall keyword search reliable for simple exact terms, dates, and numeric fragments without building hybrid search yet.

**Risk & Rollback**

Search changes can over-match or leak irrelevant results. Keep search user-scoped, keyword-only, and easy to inspect. Rollback by disabling numeric/date expansion while preserving exact text search.

**Key files**

- `apps/mobile/lib/rex/chats/**`
- `services/rex-api/app/services/chat_recall_service.py`
- `services/rex-api/app/services/chat_search_ranking.py`
- `services/rex-api/app/repositories/conversation_repository.py`
- `services/rex-api/tests/test_chat_context_service.py`
- `services/rex-api/tests/test_conversation_repository_search.py`

**Exact changes**

- Normalize search text consistently for chat title, preview, and message content.
- Ensure numeric terms like `18` are searchable and not dropped by minimum token length rules.
- Add simple date expansion for obvious month/day pairs:
  - `18` can match `June 18` and `18th`
  - `June` can match `June 18`
  - `June 18` can match `June 18th`
- Keep search strictly scoped to the current user.
- Make mobile Chats search use the same backend search behavior where possible, rather than only filtering visible local rows.
- Add regression tests for `mom`, `June`, `18`, `June 18`, `PC game`, and `Legacy of Kain`.
- Keep this as basic keyword search only. Do not add semantic or hybrid search in this fix.

**Verification commands**

```powershell
cd services/rex-api
$env:PYTHONPATH=(Get-Location).Path
pytest tests/test_chat_context_service.py tests/test_conversation_repository_search.py tests/test_memory_profile_recall.py
```

```powershell
cd apps/mobile
flutter test test/assistant_navigation_test.dart test/app_routing_test.dart
```

**Manual verification**

- In Chats, search for `mom`, `June`, `18`, `June 18`, `PC game`, and `Legacy of Kain`.
- Confirm `18` finds conversations containing `June 18` or `18th`.
- Ask Rex: `Do you have any idea of my mom's birthday?`
- Ask Rex: `What did I say about PC games?`

**Success criteria**

- Searching Chats for `18` finds conversations containing `June 18` or `18th`.
- Searching Chats for `June` and `June 18` returns the same relevant mom birthday conversation.
- Rex recall can find the older mom birthday chat when asked directly.
- Search remains simple keyword search, not a new hybrid/semantic system.
- Flat memories remain visible as fallback and chat history remains labeled as chat history, not saved memory.

## 4. Final Verification

- Deleting a saved event or flat memory removes it from active saved knowledge after backend confirmation.
- Rex does not claim deletion if the backend did not confirm it.
- Person cards aggregate only high-confidence self facts: name, location, birthday, and explicit work.
- Flat memories remain visible as fallback records.
- Person aliases are clean and do not include unrelated companies, banks, accounts, merchants, or payroll-only terms.
- Knows shows Person cards first and keeps active-only filtering consistent.
- Chat search finds `mom`, `June`, `18`, `June 18`, `PC game`, and `Legacy of Kain`.
- Rex recall searches saved knowledge and old chats before saying nothing was found.
- All changes are covered by focused backend and mobile tests.

### Final Verification Commands

```powershell
cd services/rex-api
$env:PYTHONPATH=(Get-Location).Path
pytest tests/test_chat_context_service.py tests/test_prompt_service.py tests/test_chat_simple_memory_flow.py tests/test_memory_direct_update_flow.py tests/test_memory_reliability_flow.py tests/test_memory_retrieval.py tests/test_memory_profile_recall.py tests/test_conversation_repository_search.py
```

```powershell
cd apps/mobile
flutter test test/memory_page_test.dart test/memory_api_test.dart test/memory_label_test.dart test/assistant_navigation_test.dart test/app_routing_test.dart
```

### Launch Readiness Checklist

- Delete is reliable, backend-confirmed, and tested before aggregation ships.
- Rex never claims a delete happened unless the saved item is confirmed inactive/deleted.
- Person aggregation is conservative and limited to high-confidence self facts.
- Flat memories remain visible as fallback everywhere.
- Knows shows clean Person cards without unsafe aliases.
- Active-only filtering works for flat memories, entities, and entity events.
- Chats keyword search works for basic exact, numeric, and date terms.
- Rex recall can find saved knowledge and old-chat evidence for the tested manual cases.
- No new memory system, search system, or Rex Brain path was introduced.
