# Clarity UI QA

## Automated Checks

Run from `apps/mobile`:

```bash
flutter analyze
flutter test
```

Plan 8 targeted regression subset (2026-06-25: all passed):

```bash
flutter test test/app_routing_test.dart test/assistant_navigation_test.dart test/chat_controller_test.dart test/memory_page_test.dart test/voice_call_controller_test.dart test/plaid_account_service_test.dart test/financial_read_model_service_test.dart test/accountability_api_test.dart test/assistant_financial_context_service_test.dart
```

Backend (from `services/rex-api`):

```bash
python -m pytest
```

Edge Functions (from repo root, requires Deno):

```bash
deno check supabase/functions/call-openai/index.ts
deno check supabase/functions/categorize-transactions/index.ts
deno check supabase/functions/send-mfa-security-email/index.ts
deno test --allow-env --allow-net supabase/functions/categorize-transactions/index_test.ts
```

## Manual Screenshot QA

Check these in dark mode and light mode after the appearance toggle is enabled:

- Dashboard cash flow hero and transaction rows.
- Dashboard spending pressure and account health sections.
- Accounts list, sync controls, and connected account status.
- Budgets summary, category list, and Manage categories sheet.
- Assistant Chat empty state and active conversation.
- Assistant Knows, Goals, and Chats tabs.
- Chat input bar with and without active voice.
- Voice states: listening, thinking, speaking, muted, failure, ended.
- Profile header, account actions, Rex/voice actions, appearance action, sign
  out dialog.
- Voice usage screen.

## Acceptance Criteria

- No bright blue accent remains outside theme compatibility aliases.
- Primary accent is teal/cyan and used sparingly.
- Cards are flat or softly filled by default.
- Heavy borders and nested panels are removed where they do not carry
  information.
- All existing navigation and data flows still work.
- Text remains readable in both themes.
