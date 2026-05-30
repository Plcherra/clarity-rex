# Clarity Privacy Retention And Deletion

Status: File 04 Phase 6 retention and deletion section approved for initial landing launch draft.

Purpose: explain, at a high level, how long Clarity keeps different types of information and how users can request deletion without promising automation or exact timelines that are not yet verified.

## Draft Section Title

Preferred:

- `Retention and deletion`

Acceptable alternatives:

- `How long Clarity keeps information`
- `Deleting your information`

Avoid:

- `Instant deletion`
- `We delete everything automatically`
- `Disconnecting deletes all history`

## Plain-Language Intro

Recommended draft:

> Clarity keeps information for as long as needed to provide the product, maintain user accounts, support financial organization, operate Rex, respond to requests, protect the service, comply with legal obligations, and resolve disputes.

Recommended follow-up:

> Users can request deletion of Clarity data through the Data Deletion page or support contact.

Required link:

- `/data-deletion`

## Account And Profile Retention

Recommended draft:

> Clarity keeps account and profile information while your account is active. If you request account deletion, Clarity will process the request through the published deletion workflow, subject to identity verification, legal obligations, security needs, backups, and technical constraints.

Review before launch:

- Confirm whether account deletion is self-serve, support-driven, or both.
- Confirm whether deleting the auth user cascades all user-owned database rows as expected.
- Confirm whether any vendor-side deletion steps are required.

## Financial Account And Transaction Retention

Recommended draft:

> Clarity may keep connected or imported account and transaction information while your account is active so the app can show dashboards, budgets, transaction organization, historical context, and Rex answers.

Disconnection wording:

> Disconnecting a financial account may stop future access to that account connection, but it may not automatically delete historical data already stored in Clarity unless you also request deletion.

This wording must remain unless implementation later guarantees automatic historical deletion on disconnect.

## Budget, Category, Goal, And Planning Retention

Recommended draft:

> Clarity may keep budgets, categories, goals, plans, milestones, and related progress while your account is active so the product can maintain continuity across months and conversations.

Deletion/control wording:

> Some product data may be editable, removable, archived, or deactivated inside the app. Broader account or data deletion requests should use the Data Deletion page or support contact.

## Rex Chat, Memory, And Conversation Retention

Recommended draft:

> Clarity may keep Rex conversations, assistant responses, approved memory/context, pending memory candidates, corrections, and related metadata so Rex can provide conversation history, context-aware responses, and user-reviewable memory.

Control wording:

> Certain memories or conversations may be removable, archived, or deactivated in the app where supported. Broader deletion requests should use the Data Deletion page or support contact.

Boundary:

- Do not promise every memory/conversation artifact is instantly hard-deleted unless implementation verifies that behavior.

## Voice And Audio-Derived Retention

Recommended draft:

> When you use voice features, Clarity may process audio, transcripts, generated responses, and voice metadata to provide the voice interaction. Clarity may retain transcripts, responses, or metadata where needed for conversation history, reliability, support, or security.

Review before launch:

- Confirm whether raw audio is stored, streamed only, or temporarily processed.
- Confirm what Deepgram and Google TTS retain under their provider terms/settings.
- Confirm whether Clarity stores voice turn metadata.

Boundary:

- Do not claim raw audio is never retained by Clarity or vendors until verified.

## Support, Contact, Waitlist, And Deletion Request Retention

Recommended draft:

> Clarity may keep support, contact, waitlist, privacy, security, and deletion request records as needed to respond, track requests, verify identity, maintain records, and protect the service.

Boundary:

- Do not publish exact retention periods until operational tracking is confirmed.
- Do not ask users to include bank credentials or sensitive financial identifiers in support messages.

## Logs, Security, And Backup Retention

Recommended draft:

> Clarity may keep logs, security records, error reports, backup data, and related technical information for a limited period as needed to operate, secure, debug, and improve the service.

Backup wording:

> Some information may remain in backups or logs for a limited period after deletion from active systems, subject to technical and legal constraints.

Review before launch:

- Confirm backup provider behavior.
- Confirm log retention expectations.
- Confirm whether exact timelines can be stated.

## Deletion Request Workflow

The public Privacy Policy should point to `/data-deletion` and explain:

1. User submits a deletion request.
2. Clarity may need to verify identity.
3. Clarity reviews the request scope.
4. Clarity processes deletion according to current tooling, legal obligations, security needs, backups, and technical constraints.
5. Clarity sends confirmation or follow-up through the contact path.

Avoid:

- Promising instant deletion.
- Promising deletion without identity verification.
- Promising deletion of third-party provider records unless that process is verified.

## Recommended Data Deletion Page Cross-Link

Privacy Policy copy:

> To request deletion of your Clarity account or data, visit the Data Deletion page at `/data-deletion` or contact [privacy/support email].

Footer requirement:

- Data Deletion must be a direct footer link, not only buried in the Privacy Policy.

## Open Implementation Questions

Resolve before publishing final policy:

- Is account deletion self-serve, support-driven, or both?
- Does deleting the Supabase auth user cascade all user-owned tables in production?
- What happens to Plaid items/tokens on disconnect or deletion?
- Is raw voice audio stored by Clarity, or only transcripts/metadata?
- What are current backend log and backup retention windows?
- What support/contact system will track deletion requests?
- What confirmation message is sent after deletion is complete?

## Acceptance Checklist

- Explains account, transaction, memory, chat, support, voice, log, and backup retention at a high level.
- Links to `/data-deletion`.
- Explains disconnecting Plaid/account connection does not automatically erase all stored historical data unless deletion is requested or implementation later guarantees it.
- Avoids exact timelines that are not operationally verified.
- Avoids claiming raw audio or vendor-side records are never retained unless verified.
- Flags identity verification, legal obligations, backups, and technical constraints.
