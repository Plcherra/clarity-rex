# Clarity Privacy Request Workflow

Status: File 07 Phase 5 privacy request workflow approved for initial landing launch draft.

Purpose: define the internal handling process for privacy requests submitted through `/contact`, `/data-deletion`, or the published support email.

This workflow supports:

- Access requests.
- Correction/update requests.
- Deletion requests.
- Account disconnection questions.
- Rex memory/context questions.
- Marketing/waitlist opt-out requests.
- General privacy questions.

It aligns with:

- `privacy_user_rights_and_choices.md`
- `privacy_retention_and_deletion.md`
- `data_deletion_page_contract.md`
- `contact_requirements.md`
- `form_destination_plan.md`
- `security_deletion_disconnection.md`

## Workflow Goal

Clarity needs a simple, trackable way to receive, verify, classify, act on, and confirm privacy requests.

The first version can be manual, but it must not be ad hoc. Every privacy request should have:

- A visible intake path.
- A responsible owner.
- A tracking record.
- A verification decision.
- A request category.
- An action or reason for limitation.
- A confirmation or follow-up message.

## Responsible Owner

Recommended launch owner:

- `Privacy request owner`: project owner/operator or assigned support lead.

Backup owner:

- `Technical operator`: person responsible for product/database/provider actions.

Legal review:

- Required for unusual, disputed, jurisdiction-specific, or high-risk requests.

Before public launch, define:

- Who monitors the inbox/form destination.
- Who performs verification.
- Who can perform deletion/disconnection/export actions.
- Who signs off on completed requests.
- Who handles escalations.

Do not publish personal phone numbers, private emails, or internal names unless intentionally public.

## Intake Sources

Accepted request sources:

- `/contact` form with `Privacy request`.
- `/contact` form with `Data deletion`.
- `/data-deletion` page link to contact path.
- Published support/privacy email.

Optional later sources:

- In-app account settings.
- In-app memory/conversation controls.
- Dedicated privacy request form.

Do not accept privacy requests through:

- Social media comments.
- Public issue trackers.
- Screenshots sent without context.
- Third-party messages that cannot be verified.
- Bank/provider support channels.

## Request Categories

Classify each request as one or more of:

- `access`
- `correction`
- `deletion`
- `account_disconnection`
- `memory_or_rex_context`
- `conversation_or_voice`
- `waitlist_or_contact_record`
- `marketing_opt_out`
- `security_or_unauthorized_access`
- `general_privacy_question`
- `other`

If a request includes a security issue, route it through the future security contact workflow as well.

If a request includes deletion, use `data_deletion_page_contract.md` and `privacy_retention_and_deletion.md`.

## Tracking Method

Minimum acceptable tracking:

- Internal spreadsheet.
- Support inbox labels plus a request tracker.
- Form provider submission list plus manual status tracker.
- Supabase-backed internal table if properly access-controlled.

Required tracking fields:

- `request_id`
- `received_at`
- `source`
- `requester_email`
- `request_category`
- `status`
- `owner`
- `verification_status`
- `action_taken`
- `completed_at`
- `notes`

Recommended statuses:

- `new`
- `awaiting_verification`
- `in_review`
- `action_in_progress`
- `completed`
- `limited_or_denied`
- `closed_no_response`
- `spam_or_abuse`

Do not store sensitive credentials, full account numbers, card numbers, SSNs, or one-time codes in the tracker.

## Verification Workflow

Recommended process:

1. Check whether the request came from the email associated with a Clarity account or waitlist/contact record.
2. If the requester cannot be matched, ask for limited non-sensitive information needed to verify.
3. Do not ask for bank passwords, one-time codes, full account numbers, full card numbers, SSNs, API keys, CSV files, or screenshots containing personal financial data.
4. If verification fails or the requester does not respond, mark the request as `closed_no_response` or `limited_or_denied`.
5. If the request is high-risk, ask for legal/operator review before action.

Recommended verification copy:

> To help verify this request, please contact us from the email associated with your Clarity account when possible. Do not send bank passwords, full account numbers, Social Security numbers, one-time login codes, or other sensitive secrets.

## Action Workflow

After verification, the owner should:

1. Confirm request scope.
2. Identify impacted data categories.
3. Determine whether action is supported by current tooling.
4. Apply the action or route to the technical operator.
5. Record the action and any limits.
6. Send confirmation or follow-up.

Common actions:

- Respond with general privacy information.
- Confirm waitlist/contact record status.
- Update or correct contact/waitlist details.
- Remove waitlist/contact record where appropriate.
- Initiate account/data deletion workflow.
- Guide user to app controls for memories, categories, budgets, goals, conversations, or device microphone permissions where available.
- Route account disconnection questions to support/operator workflow.
- Escalate security concerns.

## Limitation Reasons

A request may be limited, delayed, or denied when:

- Identity cannot be verified.
- Request scope is unclear.
- Legal, security, fraud-prevention, accounting, dispute, or operational retention is required.
- Backup/log retention prevents immediate removal from every copy.
- Third-party provider records are controlled by provider terms, settings, legal obligations, or verified deletion processes.
- The request seeks data belonging to another person.
- The request is abusive, fraudulent, or unsafe.

Use neutral copy. Do not accuse the requester unless necessary and reviewed.

## Confirmation Copy

Recommended completion copy:

> We have completed the privacy request we could verify and process based on the request scope. Some information may remain where retention is needed for legal, security, fraud-prevention, backup, support, or operational reasons.

Recommended follow-up-needed copy:

> We need additional non-sensitive information to verify or process your request. Please do not send bank passwords, full account numbers, Social Security numbers, one-time login codes, or other sensitive secrets.

Recommended limitation copy:

> We could not complete part of your request because of verification, legal, security, technical, provider, or operational limits. We can provide more information through the published support path where appropriate.

Do not promise:

- Instant deletion.
- Exact response deadlines unless legally reviewed and operationally supported.
- Removal from every backup or vendor record.
- Completion without verification.

## Internal Escalation Rules

Escalate to technical operator when:

- Product/database changes are needed.
- Account deletion or financial-data deletion is requested.
- Plaid/account disconnection behavior must be verified.
- Rex memory/conversation/voice records require product-specific action.
- Provider-side deletion/disconnection behavior is unclear.

Escalate to legal/operator review when:

- Request is jurisdiction-specific or cites a law.
- Request involves a dispute, legal threat, regulator, attorney, or law enforcement.
- Identity cannot be verified but the requester insists on action.
- Request involves another person's data.
- A security issue is included.

## Public Copy Alignment

The workflow must stay aligned with public copy:

- `/privacy`
- `/data-deletion`
- `/contact`
- `/security`
- `/terms`
- Footer links

If internal workflow changes, update public pages before users rely on outdated instructions.

## Launch Review Questions

Before publishing public contact/deletion pages, confirm:

- Is there a named role responsible for privacy requests?
- Is there a backup owner?
- Is the inbox/form destination monitored?
- Is there a request tracker?
- Are verification rules documented?
- Are sensitive-data warnings visible publicly and internally?
- Are deletion/disconnection requests routed correctly?
- Are security concerns escalated?
- Are confirmation templates ready?
- Does public copy avoid overpromising unsupported automation or timelines?

## Acceptance Checklist

- Request intake paths are defined.
- Privacy request owner and backup role are defined.
- Tracking method is defined.
- Verification workflow is defined.
- Request categories are defined.
- Action and escalation workflows are defined.
- Confirmation and limitation copy are defined.
- Sensitive-data handling warnings are included.
- Workflow avoids ad hoc inbox handling.
- Public Privacy, Contact, Security, Terms, and Data Deletion pages stay aligned.
