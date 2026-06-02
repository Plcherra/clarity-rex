# Memory Confirmation Contract

Last updated: June 1, 2026

## Purpose

This contract replaces hidden assistant-message confirmation markers with explicit
pending confirmation records. It is the reliability foundation for Rex's simple
memory flow:

1. Rex detects a simple, low-risk fact.
2. Rex asks a natural confirmation question.
3. The pending confirmation is stored outside message text.
4. The user's next clear confirmation saves durable memory immediately.

## Implementation Decision

Use a dedicated Supabase table named `memory_confirmations`.

Conversation metadata is rejected as the primary implementation because it would
still couple pending memory state to conversation serialization and history
loading. A real table gives the backend a stable lookup path, explicit status,
auditable timestamps, and user-scoped lifecycle management.

## Record Shape

`memory_confirmations`

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `id` | uuid | yes | Primary key. |
| `user_id` | uuid | yes | Auth user scope. |
| `conversation_id` | uuid | yes | Conversation where Rex asked for confirmation. |
| `source_message_id` | uuid | nullable | User message that triggered the pending confirmation. |
| `confirmation_message_id` | uuid | nullable | Assistant message containing the public confirmation question. |
| `status` | text | yes | One of `pending`, `confirmed`, `rejected`, `expired`, `failed`. |
| `memory_type` | text | yes | Target durable memory type, currently `fact`, `preference`, or `event`. |
| `content` | text | yes | Final durable memory sentence Rex intends to save. |
| `importance` | integer | yes | 1-5, same meaning as `long_term_memory.importance`. |
| `source` | text | yes | Detector/source name, default `simple_memory_intent`. |
| `expires_at` | timestamptz | yes | Pending confirmation expiry. Default: 48 hours. |
| `confirmed_at` | timestamptz | nullable | Set when user confirms. |
| `rejected_at` | timestamptz | nullable | Set when user rejects. |
| `failed_at` | timestamptz | nullable | Set when durable save fails after confirmation. |
| `applied_memory_id` | uuid | nullable | Durable memory record created or updated. |
| `metadata` | jsonb | yes | Topic fingerprint, entity hints, original phrase, error metadata. |
| `created_at` | timestamptz | yes | Insert timestamp. |
| `updated_at` | timestamptz | yes | Last lifecycle update. |

## Status Lifecycle

```text
pending -> confirmed
pending -> rejected
pending -> expired
pending -> failed
failed  -> confirmed    only after a retry succeeds
```

Rules:

- Only `pending` records may be acted on by a user's confirmation reply.
- A `pending` record with `expires_at <= now()` must be ignored for confirmation
  matching and may be marked `expired`.
- `confirmed`, `rejected`, and `expired` records are terminal for normal chat
  flow.
- `failed` records preserve user intent but must not be retried silently without
  a new clear user action.

## Lookup Contract

When a new user turn starts, Rex should look up:

1. Same `user_id`.
2. Same `conversation_id`.
3. `status = pending`.
4. `expires_at > now()`.
5. Newest `created_at` first.
6. Limit 1.

This intentionally avoids scanning assistant message content. It also prevents a
confirmation in one conversation from saving a pending memory from another.

## Creation Contract

When Rex detects a simple memory intent:

1. Save the user message first.
2. Create a `memory_confirmations` record.
3. Save the assistant confirmation question as plain public text.
4. Patch `confirmation_message_id` onto the confirmation record if available.
5. Return `memory_changes.confirmation_required = 1`.

New assistant messages must not include hidden `rex_memory_confirmation` markers.

## Confirmation Contract

When the user's reply is classified as confirmation:

1. Load the latest pending confirmation record.
2. Save or update durable memory from the record's `memory_type`, `content`, and
   `importance`.
3. Mark the confirmation record `confirmed`.
4. Store `applied_memory_id`.
5. Reply naturally: `Saved. I'll remember that ...`

If durable save fails:

1. Mark the confirmation record `failed`.
2. Store the failure reason in `metadata.error`.
3. Reply that Rex understood but could not save yet.

## Rejection Contract

When the user's reply is classified as rejection:

1. Load the latest pending confirmation record.
2. Mark it `rejected`.
3. Do not save durable memory.
4. Reply naturally: `No problem. I won't save that.`

## Duplicate Prevention Metadata

Each record should include a lightweight `metadata.topic_fingerprint` when
possible. For the birthday example:

```json
{
  "topic_fingerprint": "personal_fact:birthday:mom",
  "fact_kind": "birthday",
  "entity_label": "mom",
  "normalized_date": "June 18",
  "original_text": "My mom's birthday is on the 18th."
}
```

Phase 6 will use this to prevent duplicate pending confirmations and duplicate
durable memories.

## Compatibility With Existing Hidden Markers

Hidden markers are deprecated but must remain readable temporarily.

Fallback rule:

1. Try explicit `memory_confirmations` lookup first.
2. If no explicit pending record exists, inspect the latest assistant message for
   an old hidden marker.
3. If an old marker is confirmed, save durable memory as before.
4. Do not create new hidden markers.

The fallback can be removed after production conversations older than the chosen
retention window are no longer expected to contain pending hidden confirmations.

## SQL Draft For Phase 2

This is a draft. Phase 2 should convert it into the next numbered Supabase
migration after implementation review.

```sql
create table if not exists public.memory_confirmations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  conversation_id uuid not null,
  source_message_id uuid,
  confirmation_message_id uuid,
  status text not null default 'pending' check (
    status in ('pending', 'confirmed', 'rejected', 'expired', 'failed')
  ),
  memory_type text not null check (
    memory_type in ('fact', 'preference', 'event')
  ),
  content text not null,
  importance integer not null default 3 check (importance between 1 and 5),
  source text not null default 'simple_memory_intent',
  expires_at timestamptz not null default (now() + interval '48 hours'),
  confirmed_at timestamptz,
  rejected_at timestamptz,
  failed_at timestamptz,
  applied_memory_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint memory_confirmations_user_id_id_uidx unique (user_id, id),
  constraint memory_confirmations_conversation_user_fk
    foreign key (user_id, conversation_id)
    references public.conversations(user_id, id)
    on delete cascade,
  constraint memory_confirmations_source_message_user_fk
    foreign key (user_id, source_message_id)
    references public.messages(user_id, id)
    on delete set null (source_message_id),
  constraint memory_confirmations_confirmation_message_user_fk
    foreign key (user_id, confirmation_message_id)
    references public.messages(user_id, id)
    on delete set null (confirmation_message_id),
  constraint memory_confirmations_applied_memory_user_fk
    foreign key (user_id, applied_memory_id)
    references public.long_term_memory(user_id, id)
    on delete set null (applied_memory_id)
);

create index if not exists memory_confirmations_user_conversation_pending_idx
  on public.memory_confirmations (user_id, conversation_id, created_at desc)
  where status = 'pending';

create index if not exists memory_confirmations_user_status_created_idx
  on public.memory_confirmations (user_id, status, created_at desc);

create index if not exists memory_confirmations_user_topic_pending_idx
  on public.memory_confirmations (
    user_id,
    ((metadata->>'topic_fingerprint')),
    created_at desc
  )
  where status = 'pending' and metadata ? 'topic_fingerprint';
```

## Phase 1 Acceptance Check

- The implementation target is a DB table.
- The status lifecycle is explicit.
- The lookup order is explicit.
- Hidden markers are deprecated and compatibility-only.
- Phase 2 can implement a repository without changing the contract.
