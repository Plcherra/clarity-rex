# Clarity Multi-User Data Boundary

Status: Phase 6 prebuild contract  
Last updated: 2026-06-06  
Owner: Clarity product architecture and backend security

## Executive Summary

Clarity is a multi-user product. Every user-owned record must be scoped to exactly one authenticated user, and every backend write must derive `user_id` from authentication, not from client trust.

This contract defines the data boundary for Plaid, accounts, transactions, budgets, Assistant data, usage tracking, and profile data before the rebuild begins.

Core rule:

> A user may only read, write, sync, analyze, or ask the Assistant about data where the effective `user_id` is their own authenticated user id.

Service-role access is allowed only for backend-owned operations that still force user scoping internally.

## Identity Boundary

The authenticated identity is the root boundary.

- Mobile identity comes from Supabase auth.
- Backend identity comes from verified Supabase access tokens.
- Backend services must use the authenticated user id from dependencies/auth middleware.
- Client-provided `user_id` is never authoritative.
- Any table that contains user data must include either `user_id` or a primary `id` equal to `auth.uid()`.

## User-Scoped Tables

These tables must be scoped by `user_id` or `id = auth.uid()`.

| Area | Tables | Boundary |
| --- | --- | --- |
| Profile | `profiles` | `profiles.id = auth.uid()` |
| Finance core | `accounts`, `transactions`, `budgets`, `categories`, `merchant_category_rules` | `user_id = auth.uid()` |
| Imports | `account_statement_imports`, future CSV import job tables | `user_id = auth.uid()` |
| Financial audit | `financial_audit_events` | `user_id = auth.uid()` |
| Assistant chat | `conversations`, `messages`, `voice_turns` | `user_id = auth.uid()` |
| User information | `long_term_memory`, `memory_corrections`, `entities`, `entity_events`, `personal_rules` | `user_id = auth.uid()` |
| Goals and accountability | `plans`, `plan_milestones`, `commitments` | `user_id = auth.uid()` |
| Usage tracking | future `usage_events`, `usage_daily_rollups` | `user_id = auth.uid()` for user-owned reads; admin-only aggregate reads |
| Plaid | future `plaid_items`, `plaid_accounts`, `plaid_sync_cursors`, `plaid_webhook_events` | `user_id = auth.uid()` where user-owned; backend-only where token-bearing |

Legacy archived memory review tables may remain only as migration artifacts until cleanup. They must not be used by active product code.

## Direct Supabase Reads

Mobile may directly read user-owned, non-secret app data through Supabase RLS when the table has correct policies.

Allowed direct reads:

- `profiles`
- `accounts` without Plaid access tokens
- `transactions`
- `budgets`
- `categories`
- `merchant_category_rules`
- `account_statement_imports`
- `financial_audit_events`
- `conversations`
- `messages`
- `long_term_memory`
- `entities`
- `personal_rules`
- `plans`
- `plan_milestones`
- `commitments`

Direct mobile reads must never expose:

- Plaid access tokens
- Plaid item secrets
- Webhook verification secrets
- Raw LLM prompts
- Raw audio
- Internal cost/provider metadata not intended for users
- Other users' usage events

## Direct Supabase Writes

Mobile may directly write simple user-owned data only when RLS protects `user_id = auth.uid()` and the write has no privileged side effects.

Allowed direct writes:

- Profile edits.
- Category edits.
- Budget edits.
- CSV/import fallback records that do not require provider secrets.
- User-visible memory edits and archives.
- Conversation/message writes only if they remain user-owned and do not bypass Assistant policy.

Backend-owned writes are required for anything that:

- Uses third-party secrets.
- Performs provider sync.
- Generates AI output.
- Mutates multiple tables transactionally.
- Creates usage/cost records.
- Applies Assistant memory corrections from a conversation.
- Touches Plaid item/account/token tables.

## Service-Role-Only Operations

The backend may use the Supabase service role only for these operations:

| Operation | Reason | Required Guard |
| --- | --- | --- |
| Plaid link token creation | Uses Plaid secret | Authenticated backend route only |
| Plaid public token exchange | Stores access token | Use authenticated user id only |
| Plaid transaction sync | Provider secret and multi-table writes | Scope by stored item owner |
| Plaid webhook handling | Untrusted external event | Resolve item, then scope by owner |
| Usage event capture for LLM/STT/TTS/Plaid | Internal cost/latency tracking | Sanitize metadata, no raw content |
| Daily usage rollups | Internal reporting | Aggregate by user id, no content |
| Assistant direct memory save/update | Policy-controlled write path | Use auth user id from request context |
| Conversation voice turn persistence | Backend-generated metadata | Use auth user id from websocket/upload auth |
| Financial audit events created by backend workflows | Derived system events | Include user id from workflow owner |

Service-role operations must not accept a trusted `user_id` from request JSON. They must derive it from the authenticated request, stored owner record, or verified Supabase token.

## Plaid Boundary

Plaid is backend-owned.

Mobile may:

- Request a link token.
- Launch Plaid Link.
- Send `public_token` and Link metadata to the backend.
- Show connected institution/account status returned from persisted Clarity data.
- Request disconnect/resync actions through authenticated backend routes.

Mobile must not:

- Store Plaid access tokens.
- Log Plaid tokens.
- Read token-bearing Plaid tables directly.
- Send arbitrary `user_id` for Plaid operations.

Backend Plaid tables must separate user-visible account data from secrets:

- User-visible: institution name, account name, mask, subtype, sync status.
- Backend-only: access token, item id, cursor, webhook secret, raw provider payload if retained.

## Usage Tracking Boundary

Usage tracking is server-side first and privacy-preserving.

Allowed fields:

- `user_id`
- `event_type`
- `surface`
- `feature`
- `channel`
- `provider`
- `model`
- `duration_ms`
- `latency_ms`
- `status`
- `error_class`
- `cost_estimate`
- sanitized `metadata`
- `created_at`

Forbidden fields:

- Raw prompts
- Raw responses
- Transcripts
- Audio bytes or URLs
- Plaid tokens
- Account numbers
- Transaction descriptions
- Full merchant strings
- Passwords, MFA codes, auth tokens

User-facing usage reads are optional for v1. Admin/internal usage reads must be aggregate-first and must not expose raw private content.

## Assistant Data Boundary

Assistant must use the shared Clarity read models defined in `CLARITY_SHARED_READ_MODELS.md`.

The Assistant may read:

- User information shown in "What Clarity knows."
- Financial summaries derived from the same account/transaction/budget data shown in app screens.
- Goals, plans, milestones, and commitments owned by the user.
- Recent conversation history owned by the user.

The Assistant must not:

- Answer using another user's data.
- Save a fact to a different user.
- Say it does not know data that the shared read model successfully displays.
- Use legacy pending memory artifacts as a source of truth.

If the shared model is degraded or unavailable, the Assistant should say the relevant Clarity data is unavailable, not guess.

## Profile And Privacy Boundary

Profile data is user-owned.

Rules:

- Users can read/update only their own profile.
- Administrative profile access is internal-only and must be audited.
- Profile fields that affect product behavior should be reflected through shared read models.
- Private authentication data stays in Supabase auth, not app tables.

## Cross-User Test Scenarios

Every subsystem that touches user data must include cross-user tests.

Required scenarios:

1. User A cannot read User B profile.
2. User A cannot read User B accounts.
3. User A cannot read User B transactions.
4. User A cannot read User B budgets or categories.
5. User A cannot read User B Plaid connected institution status.
6. User A cannot trigger sync for User B Plaid item.
7. User A cannot disconnect User B Plaid item.
8. User A cannot read User B Assistant conversations or messages.
9. User A cannot read User B memories, entities, rules, plans, milestones, or commitments.
10. User A cannot update or archive User B memory.
11. User A correction cannot supersede User B memory.
12. User A Assistant cannot answer from User B financial read model.
13. User A mobile usage events cannot be written under User B id.
14. Non-admin users cannot read another user's usage events or rollups.
15. Plaid webhook for Item A updates only the owner resolved from stored Plaid item.
16. CSV import for User A cannot attach transactions to User B account.
17. Category/budget foreign keys must require matching `user_id`.
18. Conversation/message foreign keys must require matching `user_id`.

## RLS Requirements

All user-owned tables must have RLS enabled.

Minimum policy shape:

```sql
using (auth.uid() = user_id)
with check (auth.uid() = user_id)
```

For profile:

```sql
using (auth.uid() = id)
with check (auth.uid() = id)
```

For backend-only secret tables:

- No broad authenticated read policy.
- Backend uses service role.
- User-visible views or routes expose sanitized projections only.

## Foreign Key Requirements

Child records must preserve user ownership through composite foreign keys wherever possible.

Required pattern:

- Parent has unique `(user_id, id)`.
- Child stores `user_id`.
- Child foreign key references `(user_id, parent_id)`.

Examples:

- `transactions(user_id, account_id)` -> `accounts(user_id, id)`
- `transactions(user_id, category_id)` -> `categories(user_id, id)`
- `messages(user_id, conversation_id)` -> `conversations(user_id, id)`
- `commitments(user_id, plan_id)` -> `plans(user_id, id)`

## Implementation Checklist

- [x] Boundary covers Plaid.
- [x] Boundary covers accounts and transactions.
- [x] Boundary covers budgets and categories.
- [x] Boundary covers Assistant data.
- [x] Boundary covers usage tracking.
- [x] Boundary covers profile data.
- [x] Cross-user test scenarios are listed.
- [x] Service-role-only operations are identified.
- [x] Client-provided `user_id` is explicitly non-authoritative.
- [x] Secret-bearing Plaid data is backend-only.
