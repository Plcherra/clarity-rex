# Clarity Execution Gates

## Executive Summary

Every subsystem plan must pass the same execution gates before it is marked complete. These gates protect the one-app rebuild from drifting back into large files, duplicated truth sources, weak RLS, hidden privacy leaks, or UI changes that only work on one device.

The default rule is simple: small focused changes, one shared Clarity model, no raw private content in telemetry, no user data without authenticated ownership, and no unchecked UI phase.

## Required Gates By Phase Type

| Phase type | Required gates |
| --- | --- |
| Docs / contracts | `git diff --check`, exact affected docs reviewed, no unresolved ownerless gaps |
| Backend behavior | Focused pytest for touched service/route, full backend pytest before subsystem completion |
| Mobile behavior | Focused Flutter tests when available, `flutter analyze` before subsystem completion |
| UI / visual | `flutter analyze`, screenshot QA for major iPhone sizes, accessibility contrast pass |
| Supabase / RLS | Migration syntax review, RLS policy review, cross-user isolation tests |
| Plaid | Backend-only secret review, sandbox connect/sync/disconnect tests, webhook tests |
| Usage tracking | No-raw-content verification, per-user isolation tests, rollup correctness tests |
| Assistant / voice | Chat and voice route tests, shared model truth tests, latency/reliability checks |

## Line-Count Gate

Clarity follows the universal architecture limit: production source files should stay below 500 lines, and services/classes should usually stay below 400 lines.

Use the existing exception ledger as the source of truth:

- `docs/clarity/release_checklists/FILE_SIZE_EXCEPTION_LEDGER.md`

Before adding new behavior to a file over the limit:

1. Split the file first, or
2. Confirm the change is part of that file's cleanup phase, or
3. Add a temporary exception with owner, reason, and cleanup trigger.

Generated files are allowed only when listed in the exception ledger.

## Standard Commands

Run these from the repo root unless noted.

```bash
git diff --check
```

Backend:

```bash
cd services/rex-api
./.venv/bin/python -m pytest -q
```

Mobile:

```bash
cd apps/mobile
flutter analyze
flutter test
```

Line count scan:

```bash
rg --files apps/mobile/lib services/rex-api/app apps/web/src supabase/functions \
  -g '*.dart' -g '*.py' -g '*.ts' -g '*.tsx' -g '*.astro' \
  | rg -v '\.(g|freezed)\.dart$' \
  | xargs wc -l \
  | awk '$1 > 500 && $2 != "total" {print $0}' \
  | sort -nr
```

## Backend Gate

Backend phases must show:

- Focused tests for the touched service, route, repository, or policy.
- Full backend suite before a subsystem is complete.
- No normal chat or voice turn reintroduces a second post-turn LLM extraction call.
- No service trusts a client-provided `user_id` for user-owned writes.
- Errors include enough class/status context for debugging without logging private content.
- New route behavior is covered by route or service tests.

## Flutter Gate

Mobile phases must show:

- `flutter analyze` passes.
- Focused widget/unit tests are added when state, parsing, routing, or non-trivial UI behavior changes.
- New UI uses Clarity app-wide tokens, not feature-local Rex-only colors.
- No new app surface presents Rex as a separate product from Clarity.
- Voice, Assistant, Dashboard, Accounts, Budgets, Transactions, and Profile read from shared Clarity models where applicable.

## Screenshot QA Gate

UI phases must include screenshot review before completion when visual structure changes.

Required device families:

- Small iPhone viewport.
- Current primary iPhone viewport.
- Large iPhone viewport.

Review checklist:

- Text does not overflow, clip, or overlap.
- Bottom navigation and input areas respect safe areas.
- Empty, loading, success, and error states are visible and calm.
- Dark theme contrast is readable.
- Financial green/red is reserved for money state, not general decoration.
- Cards, pills, and borders are restrained and consistent with the design token contract.

## Privacy Gate

No phase may store or log:

- Raw prompts or assistant responses in usage tracking.
- Voice audio or raw transcripts in usage tracking.
- Plaid access tokens, public tokens, account numbers, or routing numbers.
- Full transaction descriptions in usage tracking metadata.
- Passwords, OTPs, MFA secrets, or auth tokens.

Allowed usage tracking fields are limited to safe counters and timing data such as:

- `user_id`
- `event_type`
- `surface`
- `feature`
- `channel`
- `duration_ms`
- `latency_ms`
- `status`
- `error_class`
- sanitized `metadata`

## RLS And Multi-User Gate

Any phase touching user-owned data must verify:

- Every user-owned table has a user scope.
- Direct Supabase reads are limited to `auth.uid()`.
- Backend/service-role writes derive user identity from verified auth context.
- Plaid sync, webhook, and token exchange routes cannot write across users.
- Assistant memory, goals, conversations, and voice turns cannot cross user boundaries.
- Usage events and rollups are private to the owning user unless accessed through an explicit admin/internal path.

Cross-user tests must cover at least:

- User A cannot read User B accounts, transactions, budgets, goals, memories, conversations, or usage rows.
- User A cannot update or delete User B data.
- Assistant cannot answer User A with User B facts.
- Plaid webhook handling cannot mutate the wrong user's item.

## Assistant Truth Gate

Assistant phases must prove truth parity:

- If Clarity displays a fact, account, budget, transaction summary, goal, or plan, Assistant must not claim it does not know it.
- Assistant must use shared Clarity read models instead of separate memory guesses.
- Corrections update existing records where possible instead of creating duplicates.
- Voice and chat use the same brain/context path unless a documented fallback is active.

## Subsystem Completion Gate

A subsystem plan is complete only when:

1. All changed files are under line-count limits or listed in the exception ledger.
2. Focused tests for changed behavior pass.
3. Full backend and/or Flutter gates pass for that subsystem's surface.
4. Privacy and RLS gates pass when user-owned or sensitive data changed.
5. UI screenshot QA is complete for visual phases.
6. Remaining known gaps are assigned to a later subsystem plan.

