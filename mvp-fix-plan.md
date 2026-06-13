# MVP Fix Plan

## 1. All Transactions Must Be Categorized

Issue:
Plaid and imported transactions can still reach Clarity as `Unknown`, `Other`, `Uncategorized`, or `Needs category`. This is legacy review-queue behavior from the first version of the app. For the Plaid MVP, users should not have to review uncategorized transactions manually.

Files:
- `/Users/pedromartins/Desktop/clarity-rex/services/rex-api/app/services/plaid_category_mapper.py`
- `/Users/pedromartins/Desktop/clarity-rex/services/rex-api/app/services/plaid_transaction_sync.py`
- `/Users/pedromartins/Desktop/clarity-rex/apps/mobile/lib/features/transactions/domain/spend_categories.dart`
- `/Users/pedromartins/Desktop/clarity-rex/apps/mobile/lib/features/transactions/domain/transaction_resolution.dart`
- `/Users/pedromartins/Desktop/clarity-rex/apps/mobile/lib/features/transactions/domain/transaction_review.dart`
- `/Users/pedromartins/Desktop/clarity-rex/apps/mobile/lib/features/transactions/application/category_workflow_service.dart`
- `/Users/pedromartins/Desktop/clarity-rex/apps/mobile/lib/rex/data/rex_financial_transaction_policy.dart`
- `/Users/pedromartins/Desktop/clarity-rex/apps/mobile/lib/rex/data/financial_context_service.dart`
- `/Users/pedromartins/Desktop/clarity-rex/services/rex-api/app/services/prompt_financial_context.py`

Fix Needed:
- Use Plaid category data when available, mapped into Clarity's category model.
- Apply deterministic merchant/category rules before any transaction reaches the dashboard, budgets, or Rex.
- Use AI categorization only as a controlled fallback when Plaid and deterministic rules are not enough.
- Persist the final category so Dashboard, Accounts, Budgets, Transactions, and Rex all see the same result.
- Remove `Unknown`, `Other`, `Uncategorized`, and `Needs category` from normal user-facing financial truth.
- Keep a backend/internal degraded-state signal for any rows that still fail categorization, but do not present it as a normal category or user task.
- Update Rex so unresolved rows are treated as a data-quality problem, not as something the user should manually review.
- Add tests proving Plaid transactions, CSV transactions, and manual transactions resolve to a real category before they appear in financial read models.

Goal After Fix:
100% of visible financial transactions have a real category. Rex and the financial UI never disagree about category truth, and Rex does not mention uncategorized transactions unless categorization failed and the data is explicitly marked degraded.

Priority:
High

## 2. Memory Retrieval Can Silently Fail

Issue:
Memory retrieval can silently fail and make Rex say it does not know something.

Files:
- `/Users/pedromartins/Desktop/clarity-rex/services/rex-api/app/services/chat_context_service.py`
- `/Users/pedromartins/Desktop/clarity-rex/services/rex-api/app/services/memory_service.py`
- `/Users/pedromartins/Desktop/clarity-rex/services/rex-api/app/services/memory_retrieval_ranker.py`
- `/Users/pedromartins/Desktop/clarity-rex/services/rex-api/tests/test_chat_context_service.py`

Fix Needed:
- Replace silent empty-memory fallbacks with explicit degraded context when memory or chat search fails.
- Make old-chat search reliable for people, family, places, events, goals, and preferences.
- Add tests for questions like “Do you know anything about my mom?” and “What do you know about me?”

Goal After Fix:
Rex only says “I do not know” when memory search actually succeeded and found nothing. If search fails, Rex says memory is unavailable or degraded.

Priority:
High

## 3. Rex Can Claim Memory Updates Without Durable Confirmation

Issue:
Rex can claim memory updates were saved even when the backend did not confirm the durable write.

Files:
- `/Users/pedromartins/Desktop/clarity-rex/services/rex-api/app/services/memory_intent_service.py`
- `/Users/pedromartins/Desktop/clarity-rex/services/rex-api/app/services/memory_correction_service.py`
- `/Users/pedromartins/Desktop/clarity-rex/services/rex-api/app/services/memory_discipline_service.py`
- `/Users/pedromartins/Desktop/clarity-rex/services/rex-api/tests/test_memory_turn_service.py`

Fix Needed:
- Require backend confirmation before Rex says a fact was saved, updated, corrected, or deleted.
- Make corrections update the visible “What Clarity Knows” record.
- Add tests for city correction, birthday memory, and reminder-style memory.

Goal After Fix:
When Rex says it saved or fixed memory, the user can immediately see that change reflected in the app.

Priority:
High

## 4. Rex Action Truth Is Still Risky

Issue:
Rex action truth is still risky because advertised controls may not match backend support.

Files:
- `/Users/pedromartins/Desktop/clarity-rex/apps/mobile/lib/rex/data/financial_context_service.dart`
- `/Users/pedromartins/Desktop/clarity-rex/services/rex-api/app/services/clarity_control_service.py`
- `/Users/pedromartins/Desktop/clarity-rex/services/rex-api/app/services/rex_intent_router.py`
- `/Users/pedromartins/Desktop/clarity-rex/services/rex-api/app/services/chat_service.py`

Fix Needed:
- Audit every action Rex can mention or route.
- Remove unsupported actions from prompts and context.
- Require confirmation for risky actions and backend confirmation before success language.

Goal After Fix:
Rex only offers actions the app can actually execute, and never fakes completion.

Priority:
High

## 5. Manage Categories Scroll Bug

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

## 6. Account Cards Are Still Too Crowded

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

## 7. Dashboard Controls And Spacing Need Polish

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

## 8. Chats Tab Needs Search And Better Organization

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

## 9. PDF Upload Is Not Supported

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

## 10. Voice Feels Slow And Robotic

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

## 11. Rex And Finance Use Separate Visual Token Systems

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

## 12. Large App-Critical Files Increase Launch Risk

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
