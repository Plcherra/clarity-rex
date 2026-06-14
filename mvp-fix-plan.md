# MVP Fix Plan

This plan is organized by launch priority groups. Work one full group at a time, starting with Group 1.

Issue 1 is complete and removed from active MVP work. Active tracking now starts at Issue 2.

## Group 1: Core Trust & Truth Issues (Highest Priority)

High-Level Overview of Rex Memory System (MVP Scope):
Rex's production brain for launch consists of exactly two paths. There is no other orchestration.

- Direct memory path: deterministic saves and updates handled by backend code before the LLM answers.
- Context + LLM path: retrieval for questions, where Rex loads saved memory, structured memory, old chat evidence, recent conversation context, goals, and finance context before answering.

**MVP Launch Rule (non-negotiable for fast launch):**
The advanced Rex Brain routing system (RexThinkingRouter, multi-layer decisions FAST/ANALYTICAL/STRATEGIC/etc., separate brain context selection, layer-specific routing contracts, and dynamic model+budget routing) is disabled.
The single hardened base path above (direct memory + unified context assembly in chat_context_service + prompt_service + action truth post-processing) is the *only* path exercised in production for launch. All truth guarantees from this Group apply to this one path only.

Main remaining weaknesses for launch (base path only):

- Old-chat recall is still weak because it is keyword-based and can miss context.
- Memory correction is fragile when voice transcription is wrong or partial.
- Bad or garbled memories can persist in the database if they were saved before the newer guards.
- Rex and the "Knows" screen can show different information because Rex can use old chat evidence that is not saved memory.
- Retrieval is not unified or smart enough yet; saved facts, old chats, recent context, and structured memory still travel through separate paths.

### Issue 2: Memory Retrieval Can Silently Fail

Issue:
Memory retrieval was recently improved, but Rex can still appear confident when memory/chat search is incomplete, unavailable, not actually checked, or based only on weak keyword old-chat matching.

Files:
- `/Users/pedromartins/Desktop/clarity-rex/services/rex-api/app/services/chat_context_service.py`
- `/Users/pedromartins/Desktop/clarity-rex/services/rex-api/app/services/memory_service.py`
- `/Users/pedromartins/Desktop/clarity-rex/services/rex-api/app/services/memory_retrieval_ranker.py`
- `/Users/pedromartins/Desktop/clarity-rex/services/rex-api/app/services/conversation_repository.py`
- `/Users/pedromartins/Desktop/clarity-rex/services/rex-api/app/services/prompt_memory_context.py`
- `/Users/pedromartins/Desktop/clarity-rex/services/rex-api/tests/test_chat_context_service.py`
- `/Users/pedromartins/Desktop/clarity-rex/services/rex-api/tests/test_memory_profile_recall.py`

(Note: Advanced Rex Brain files belong to the disabled layer — see Issue 4b. MVP uses only the base context + prompt path. Do not expand work here.)

Fix Needed:
- Keep memory and old-chat retrieval explicit for people, family, places, events, goals, and preferences.
- Label old-chat excerpts as evidence, not confirmed saved facts.
- Search old chats with safer fallback queries for family/date/relationship questions.
- Replace silent empty-memory fallbacks with degraded context when memory/chat search fails.
- Make Rex distinguish between "I searched and found nothing" and "I could not access memory."
- Keep validating questions like "Do you know anything about my mom?" and "What do you know about me?"

Goal After Fix:
Rex only says it does not know when memory search actually succeeded and found nothing. If search fails, Rex clearly says memory is unavailable or degraded.

Priority:
High

### Issue 3: Rex Can Claim Memory Updates Without Durable Confirmation

Issue:
Rex can claim memory updates were saved, corrected, or deleted even when the backend did not confirm the durable write. Bad voice transcripts can also create or preserve nonsense memory rows.

Files:
- `/Users/pedromartins/Desktop/clarity-rex/services/rex-api/app/services/memory_intent_service.py`
- `/Users/pedromartins/Desktop/clarity-rex/services/rex-api/app/services/memory_turn_direct_helpers.py`
- `/Users/pedromartins/Desktop/clarity-rex/services/rex-api/app/services/memory_correction_service.py`
- `/Users/pedromartins/Desktop/clarity-rex/services/rex-api/app/services/memory_discipline_service.py`
- `/Users/pedromartins/Desktop/clarity-rex/services/rex-api/tests/test_memory_turn_service.py`
- `/Users/pedromartins/Desktop/clarity-rex/services/rex-api/tests/test_chat_simple_memory_flow.py`

(Note: Advanced Rex Brain files are disabled for MVP — see Issue 4b. Only the direct memory path matters for launch.)

Fix Needed:
- Require backend confirmation before Rex says a fact was saved, updated, corrected, or deleted.
- Make corrections update the visible "What Clarity Knows" record.
- Block unclear voice/location fragments from being saved as memory.
- Archive or supersede obviously corrupted location facts when a clean location correction is confirmed.
- If a memory write fails, Rex must say it failed instead of pretending it worked.
- Add/keep tests for city correction, birthday memory, and reminder-style memory.

Goal After Fix:
When Rex says it saved or fixed memory, the user can immediately see that change reflected in the app.

Priority:
High

### Issue 4: Rex Action Truth Is Still Risky

Issue:
Rex action truth is still risky because advertised actions may not match what the backend can actually execute.

Files:
- `/Users/pedromartins/Desktop/clarity-rex/apps/mobile/lib/rex/data/financial_context_service.dart`
- `/Users/pedromartins/Desktop/clarity-rex/services/rex-api/app/services/clarity_control_service.py`
- `/Users/pedromartins/Desktop/clarity-rex/services/rex-api/app/services/rex_intent_router.py`
- `/Users/pedromartins/Desktop/clarity-rex/services/rex-api/app/services/chat_service.py`
- `/Users/pedromartins/Desktop/clarity-rex/services/rex-api/app/services/prompt_constants.py`

Fix Needed:
- Audit every action Rex can mention, suggest, or route.
- Remove unsupported actions from prompts and context.
- Require user confirmation before risky or durable actions.
- Require backend confirmation before success language.

Goal After Fix:
Rex only offers actions the app can actually execute, and never fakes completion.

Priority:
High

### Issue 4b: Advanced Rex Brain Routing Deferred — Use Base Path Only (Launch Scope Lock)

This is the final Group 1 item required before any Group 2 work or launch validation. It makes the orchestration simple so the trust fixes in Issues 2-4 are easy to reason about, test, and ship fast.

Issue:
The full Rex Brain layer (router, decision builder, brain-specific context selection/budgeting, per-layer prompt contracts, rollout machinery) is a large parallel system on top of the now-hardened base path. It increases test surface, maintenance cost, and risk of subtle truth violations. It is already disabled by default and was never the primary path.

For fast MVP launch we lock to one simple brain:

- Always run direct memory + goal short-circuits first.
- One context assembly (chat_context_service).
- One prompt build (prompt_service + MEMORY_DISCIPLINE_PROMPT + personality).
- Post-LLM truth enforcement (action_truth_policy + clarity_action_parser) on every generated response.
- Model choice limited to static config (GROK_FAST_MODEL / standard) or explicit user "deep think" hints — no dynamic multi-layer routing.

Files (minimal surface for this item):
- `/Users/pedromartins/Desktop/clarity-rex/services/rex-api/app/services/chat_service.py`
- `/Users/pedromartins/Desktop/clarity-rex/services/rex-api/app/services/chat_context_service.py`
- `/Users/pedromartins/Desktop/clarity-rex/services/rex-api/app/services/prompt_constants.py`
- `/Users/pedromartins/Desktop/clarity-rex/services/rex-api/app/services/prompt_service.py`
- `/Users/pedromartins/Desktop/clarity-rex/services/rex-api/app/config.py`
- `services/rex-api/.env.example` and `mobile.env.example`
- `services/rex-api/README.md`
- Relevant brain files may stay in tree but must not be called from the main chat/stream paths for launch.

Fix Needed (small, contained, 1-3 focused changes):
- In the primary `message` and `stream_message` paths: keep the memory_turn + goal short-circuits. Remove or make no-op the calls to `rex_brain_chat_service.safe_plan_chat_turn`, `apply_chat_contract`, brain `prompt_context` reshaping, and `build_prompt_messages_for_rex_brain`.
- Always fall through to the standard `chat_context_service` + `prompt_service.build_messages` path + existing truthful post-processing.
- Update config/env so `REX_BRAIN_ROUTING_ENABLED=false` and `REX_BRAIN_ROLLOUT_STAGE=disabled` are the only supported launch values (add clear comments "MVP: base path only").
- Merge the strongest reusable safety language from the brain layer prompts ("admit when memory/context missing", "never claim action without execution metadata", etc.) into the single base `MEMORY_DISCIPLINE_PROMPT` and `REX_PERSONALITY_PROMPT`.
- Verify (tests + manual + smoke): only the base two-path orchestration is active. Advanced brain planning must not affect any launch response.
- Update README and any readiness notes to state "Advanced Rex Brain routing is experimental and disabled for MVP."

Goal After Fix:
One simple, trustworthy orchestration path for the entire MVP. All Group 1 truth guarantees are easy to maintain. Launch validation, Group 2 polish, and prod smoke tests have minimal surface area. The advanced brain system can be revisited cleanly after real users are on the reliable base.

Priority:
High (complete this before declaring Group 1 done and moving to Group 2)

## Group 2: UX Polish & Usability

### Issue 5: Manage Categories Scroll Bug

Issue:
Manage Categories cannot reliably scroll to all saved categories on device.

Files:
- `/Users/pedromartins/Desktop/clarity-rex/apps/mobile/lib/features/budgets/presentation/budgets_screen.dart`
- `/Users/pedromartins/Desktop/clarity-rex/apps/mobile/lib/features/budgets/presentation/category_management_sheet.dart`
- `/Users/pedromartins/Desktop/clarity-rex/apps/mobile/lib/features/budgets/presentation/category_management_sheet_sections.dart`

Fix Needed:
- Rework the category management modal so content has one predictable scroll container.
- Verify the list reaches the final category on small iPhone screens.
- Keep tabs and the add button usable without blocking list scroll.

Goal After Fix:
Users can open Manage Categories and scroll through every saved category without layout traps.

Priority:
High

### Issue 6: Account Cards Are Still Too Crowded

Issue:
Account cards still feel crowded and can make account identity hard to read.

Files:
- `/Users/pedromartins/Desktop/clarity-rex/apps/mobile/lib/core/models/account.dart`
- `/Users/pedromartins/Desktop/clarity-rex/apps/mobile/lib/features/accounts/presentation/widgets/plaid_account_header.dart`
- `/Users/pedromartins/Desktop/clarity-rex/apps/mobile/lib/features/accounts/presentation/widgets/plaid_account_tile.dart`
- `/Users/pedromartins/Desktop/clarity-rex/apps/mobile/lib/features/accounts/presentation/accounts_screen.dart`

Fix Needed:
- Keep the shared display name format: institution + account type + mask.
- Give the account title more horizontal space.
- Move secondary metadata and actions so they do not crowd the account name.
- Verify the same display name is used by Rex and the UI.

Goal After Fix:
Users can instantly recognize each account, and Rex uses the exact same account names.

Priority:
High

### Issue 7: Dashboard Controls And Spacing Need Polish

Issue:
Dashboard still has unnecessary controls and spacing that make the financial area feel unpolished.

Files:
- `/Users/pedromartins/Desktop/clarity-rex/apps/mobile/lib/features/dashboard/presentation/financial_dashboard_shell.dart`
- `/Users/pedromartins/Desktop/clarity-rex/apps/mobile/lib/features/dashboard/presentation/financial_dashboard_transaction_controls.dart`
- `/Users/pedromartins/Desktop/clarity-rex/apps/mobile/lib/features/dashboard/presentation/financial_dashboard_transactions.dart`
- `/Users/pedromartins/Desktop/clarity-rex/apps/mobile/lib/features/dashboard/presentation/dashboard_screen.dart`

Fix Needed:
- Reduce empty space above the Overview section.
- Remove unnecessary Budgets shortcut from the dashboard overview.
- Remove or hide the Rows transaction mode unless it is truly needed.
- Keep Months and Categories as the primary transaction views.

Goal After Fix:
The dashboard feels intentional, compact, and launch-ready.

Priority:
High

### Issue 11: Rex And Finance Use Separate Visual Token Systems

Issue:
Rex and finance screens still use separate visual token systems.

Files:
- `/Users/pedromartins/Desktop/clarity-rex/apps/mobile/lib/app/app.dart`
- `/Users/pedromartins/Desktop/clarity-rex/apps/mobile/lib/rex/presentation/rex_ui_tokens.dart`
- `/Users/pedromartins/Desktop/clarity-rex/apps/mobile/lib/rex/presentation/rex_surfaces.dart`
- `/Users/pedromartins/Desktop/clarity-rex/apps/mobile/lib/features/dashboard/presentation/financial_dashboard_view.dart`
- `/Users/pedromartins/Desktop/clarity-rex/apps/mobile/lib/features/accounts/presentation/accounts_screen.dart`

Fix Needed:
- Make Rex surfaces and financial screens share one practical dark design system.
- Keep spacing, card borders, typography, and accent colors consistent.
- Avoid making Rex feel polished while finance feels separate.

Goal After Fix:
Clarity feels like one app, with Rex and finance using the same visual language.

Priority:
Medium

## Group 3: Nice-to-Have

### Issue 8: Chats Tab Needs Search And Better Organization

Issue:
Chats tab is hard to use for old conversations.

Files:
- `/Users/pedromartins/Desktop/clarity-rex/apps/mobile/lib/rex/chat/presentation/pages/conversation_list_page.dart`
- `/Users/pedromartins/Desktop/clarity-rex/apps/mobile/lib/rex/chat/presentation/widgets/conversation_history_widgets.dart`
- `/Users/pedromartins/Desktop/clarity-rex/apps/mobile/lib/rex/chat/application/conversation_list_controller.dart`

Fix Needed:
- Add search by conversation title and message text.
- Improve grouping by date with clear day, month, and year labels.
- Avoid messy endless lists by adding better sectioning and empty states.

Goal After Fix:
Users can find old Rex conversations quickly and trust that past context is accessible.

Priority:
Medium

### Issue 9: PDF Upload Is Not Supported

Issue:
PDF upload is not supported in Rex attachments.

Files:
- `/Users/pedromartins/Desktop/clarity-rex/apps/mobile/lib/rex/chat/domain/chat_attachment.dart`
- `/Users/pedromartins/Desktop/clarity-rex/apps/mobile/lib/rex/chat/presentation/pages/chat_page.dart`
- `/Users/pedromartins/Desktop/clarity-rex/services/rex-api/app/services/file_service.py`
- `/Users/pedromartins/Desktop/clarity-rex/services/rex-api/app/routes/chat.py`

Fix Needed:
- Add PDF as an allowed attachment type or explicitly defer it from MVP.
- If included, extract text safely on the backend and enforce file-size limits.
- Show clear upload errors when a PDF cannot be read.

Goal After Fix:
Users can attach images and PDFs, or the app clearly communicates that PDFs are not part of MVP.

Priority:
Medium

### Issue 10: Voice Feels Slow And Robotic

Issue:
Voice feels slow and robotic.

Files:
- `/Users/pedromartins/Desktop/clarity-rex/apps/mobile/lib/rex/voice/application/voice_call_controller_streaming.dart`
- `/Users/pedromartins/Desktop/clarity-rex/apps/mobile/lib/rex/voice/data/streaming_audio_playback_queue.dart`
- `/Users/pedromartins/Desktop/clarity-rex/services/rex-api/app/services/voice_stream_session.py`
- `/Users/pedromartins/Desktop/clarity-rex/services/rex-api/app/services/voice_stream_response_writer.py`
- `/Users/pedromartins/Desktop/clarity-rex/services/rex-api/app/services/google_tts_service.py`
- `/Users/pedromartins/Desktop/clarity-rex/services/rex-api/app/config.py`

Fix Needed:
- Measure first-audio latency and full response latency.
- Tune chunking so Rex starts speaking sooner.
- Adjust speech rate and voice settings for a more natural pace.
- Add a safe fallback when streaming voice fails.

Goal After Fix:
Voice feels responsive enough for daily use and does not sound painfully slow.

Priority:
Medium

## Group 4: Technical Debt (Do Last)

### Issue 12: Large App-Critical Files Increase Launch Risk

Issue:
Large app-critical files make launch fixes risky.

Files:
- `/Users/pedromartins/Desktop/clarity-rex/apps/mobile/lib/app/ui_dependencies.dart`
- `/Users/pedromartins/Desktop/clarity-rex/apps/mobile/lib/features/transactions/presentation/widgets/transaction_category_dropdown.dart`
- `/Users/pedromartins/Desktop/clarity-rex/apps/mobile/lib/features/dashboard/presentation/transaction_review_screen.dart`
- `/Users/pedromartins/Desktop/clarity-rex/apps/mobile/lib/rex/data/financial_context_service.dart`
- `/Users/pedromartins/Desktop/clarity-rex/services/rex-api/app/services/chat_context_service.py`
- `/Users/pedromartins/Desktop/clarity-rex/services/rex-api/app/services/memory_intent_service.py`
- `/Users/pedromartins/Desktop/clarity-rex/services/rex-api/app/services/chat_service.py`

Fix Needed:
- Do not do broad refactors before fixing user-facing trust bugs.
- After high-priority issues are fixed, split only the files directly blocking safe development.
- Start with context/memory/financial files because they affect Rex truth.

Goal After Fix:
The app remains stable for MVP while the riskiest files become easier to maintain.

Priority:
Low
