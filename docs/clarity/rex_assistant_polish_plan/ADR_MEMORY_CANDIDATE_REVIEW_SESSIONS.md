# Architecture Decision Record: Memory Candidate Review Sessions

Status: Accepted

Date: June 2, 2026

Owner: Clarity

Related module/plan: `docs/clarity/rex_assistant_polish_plan/REX_PRODUCTION_READINESS_FOLLOWUP_PLAN.md`

## Context

Rex can ask the user to review pending memory candidates and the user may reply
with natural language such as `confirm those as saved` or `save them`. Before
this decision, the backend could include a lightweight `review_session` payload
in the response, but that state was not persisted. If another request happened
between listing and confirmation, Rex could only infer intent from the current
pending candidates in the conversation.

This is fragile because the user is referring to a specific reviewed set, not
necessarily every pending candidate in the conversation.

## Decision

We will persist explicit memory candidate review sessions in a small
user-scoped table, `memory_candidate_review_sessions`.

Each session stores:

- `conversation_id`
- `candidate_ids`
- `status`
- `expires_at`
- safe metadata such as high-risk candidate IDs

The session stores candidate IDs only, not full memory content.

## Options Considered

| Option | Pros | Cons | Decision |
| --- | --- | --- | --- |
| Conversation metadata | Lightweight and no new concept | Conversations do not currently have metadata; adding it makes unrelated conversation rows carry workflow state | Rejected |
| Candidate `decision` JSON | No new table | Spreads one review operation across many candidate rows and is hard to expire cleanly | Rejected |
| Existing `memory_confirmations` table | Already models simple-memory confirmation | Different domain and columns are tailored to simple long-term memory facts | Rejected |
| Dedicated review-session table | Explicit, inspectable, easy to expire, user-scoped | Adds one migration and repository | Chosen |

## Rationale

The dedicated table is the clearest fit for the product behavior. It keeps the
review operation explicit, avoids hidden prompt markers, and lets Rex resolve
pronouns like `those`, `these`, and `them` against the reviewed candidate IDs.

This also matches the Universal Code Architecture Standards: explicit state,
small modules, no silent failure, and durable workflow records for user-critical
operations.

## Consequences

### Positive

- Rex can recover review state across requests.
- Bulk confirmation affects the reviewed set, not every pending item.
- High-risk candidates remain visible and individually confirmable.

### Negative

- Adds one small table and repository.
- Requires a migration before production deployment.

### Neutral / Operational

- Sessions are short-lived and can be expired by status or `expires_at`.
- If session persistence fails, Rex can still show pending candidates but should
  not rely on hidden state.

## Implementation Notes

Files or systems affected:

- `supabase/migrations/000024_create_memory_candidate_review_sessions.sql`
- `services/rex-api/app/services/memory_candidate_review_session_repository.py`
- `services/rex-api/app/services/memory_candidate_review_session_service.py`
- `services/rex-api/app/services/memory_candidate_decision_service.py`
- `services/rex-api/app/services/memory_candidate_decision_formatter.py`

Migration or rollout plan:

1. Deploy migration.
2. Deploy backend.
3. Confirm phone flow: list pending memories, send another chat turn, then say
   `confirm those as saved`.

Rollback plan:

1. Disable session service injection or remove backend usage.
2. Keep table harmlessly unused.
3. Fall back to existing candidate review behavior.

## Validation

How we will know the decision worked:

- Tests prove `confirm those as saved` uses persisted session candidate IDs.
- Tests prove high-risk candidates in the session are skipped unless explicitly
  confirmed.
- Manual phone test confirms pending count does not grow or apply unrelated
  candidates.

Required tests:

- Candidate decision service resolves `those/them` from session.
- Review response creates a session.
- Missing session gracefully falls back to current pending review response.

## Revisit Trigger

Revisit this decision when:

- Session volume becomes large enough to require scheduled cleanup.
- The app needs multiple simultaneous review sessions in one conversation.
- Mobile begins managing candidate review sessions directly.

## Follow-Up Tasks

- [ ] Add operational cleanup for expired sessions if needed.
- [ ] Add mobile UI affordance for the active review session if useful.

