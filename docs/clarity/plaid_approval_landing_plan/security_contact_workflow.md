# Clarity Security Contact Workflow

Status: File 07 Phase 6 security contact workflow approved for initial landing launch draft.

Purpose: define how Clarity should receive, track, triage, escalate, and respond to security reports submitted through `/contact`, `/security`, `/data-deletion`, or the published support/security email.

This workflow aligns with:

- `security_incident_support_language.md`
- `contact_requirements.md`
- `privacy_request_workflow.md`
- `form_destination_plan.md`
- `security_review_gate.md`
- `terms_acceptable_use.md`

## Workflow Goal

Clarity needs a clear security reporting path before the landing site is used for Plaid review.

The first version can be simple and manual, but it must define:

- Where reports arrive.
- Who monitors them.
- How reports are categorized.
- How urgent issues are escalated.
- What users/reporters should not send.
- How follow-up is handled.
- What claims must not be made publicly.

This is not a formal bug bounty or safe-harbor program unless Clarity later creates and legally reviews one.

## Public Reporting Path

Recommended public route:

- `/contact` with reason `Security concern`.

Supporting routes:

- `/security` security contact section.
- `/data-deletion` for privacy/deletion-adjacent issues.
- Published support/security email if available and monitored.

Recommended public copy:

> To report a security concern, suspected unauthorized access, privacy issue, or deletion question, contact Clarity through `/contact` or the published support email. Choose `Security concern` when available and include enough non-sensitive detail for follow-up.

Required warning:

> Do not send bank passwords, full account numbers, full card numbers, Social Security numbers, one-time login codes, API keys, private keys, or other sensitive secrets through public forms or email.

## Responsible Owner

Recommended launch owner:

- `Security contact owner`: project owner/operator or assigned technical lead.

Backup owner:

- `Support/privacy owner`: monitors incoming messages and escalates security-tagged reports.

Legal/operator review:

- Required for vulnerability disclosure, account compromise, legal threats, regulator/law-enforcement contact, safe-harbor language, or public incident communication.

Before public launch, define:

- Who monitors the inbox/form destination.
- Who can inspect logs or provider dashboards.
- Who can rotate keys or credentials if needed.
- Who can disable public forms or affected features.
- Who communicates with the reporter.

Do not publish personal phone numbers, private emails, private chat handles, or internal escalation names unless intentionally public.

## Report Categories

Classify incoming reports as one or more of:

- `suspected_unauthorized_access`
- `vulnerability_report`
- `phishing_or_impersonation`
- `privacy_or_deletion_issue`
- `connected_account_issue`
- `voice_or_chat_privacy_issue`
- `contact_form_abuse`
- `credential_or_secret_exposure`
- `spam_or_noise`
- `other_security_concern`

If the report is primarily a privacy request, route it through `privacy_request_workflow.md` as well.

If the report is primarily product support, classify it as support but keep a note if it includes security context.

## Severity Guide

Use a simple internal severity label:

- `critical`
  - Active account compromise, exposed production secrets, unauthorized access to user data, payment/financial account misuse, or exploitable production vulnerability.

- `high`
  - Plausible vulnerability involving private data, authentication/session issues, provider/token exposure risk, or repeated suspicious access reports.

- `medium`
  - Security bug with limited impact, suspicious email/report needing investigation, privacy-impacting bug with no confirmed data exposure.

- `low`
  - General security question, unclear report, non-sensitive misconfiguration, spam, or unsupported claim.

Severity should be revisited as facts become clearer.

Do not expose internal severity labels publicly unless intentionally reviewed.

## Intake And Tracking

Minimum tracking method:

- Support inbox labels plus a security tracker.
- Internal spreadsheet.
- Form provider submission list plus manual tracker.
- Internal database/table only if access-controlled.

Required tracking fields:

- `security_report_id`
- `received_at`
- `source`
- `reporter_email`
- `category`
- `severity`
- `status`
- `owner`
- `summary`
- `non_sensitive_reproduction_steps`
- `action_taken`
- `follow_up_needed`
- `closed_at`

Recommended statuses:

- `new`
- `triaging`
- `needs_reporter_follow_up`
- `investigating`
- `mitigating`
- `monitoring`
- `closed`
- `spam_or_invalid`

Do not store secrets, full account numbers, full card numbers, SSNs, one-time login codes, raw tokens, or private keys in the tracker.

## Triage Workflow

Recommended process:

1. Confirm the report arrived through a monitored path.
2. Record the report in the tracker.
3. Remove or quarantine any sensitive secrets accidentally included, where feasible.
4. Categorize the report.
5. Assign initial severity.
6. Identify whether privacy/deletion workflow also applies.
7. Assign owner.
8. Determine immediate mitigation, if any.
9. Send a conservative acknowledgement when appropriate.
10. Track investigation, action, and closure.

If a report includes a production secret or credential, prioritize containment and rotation before broad discussion.

## Reporter Guidance

Recommended acknowledgement:

> Thanks for reporting this. We will review the information provided through the published support path. Please do not send passwords, full account numbers, one-time login codes, API keys, private keys, or sensitive user data.

If more information is needed:

> If safe to share, please provide the affected page or feature, a short description, and non-sensitive steps to reproduce. Do not access, copy, publish, or share data that you are not authorized to use.

Avoid:

- Promising a reward.
- Promising safe harbor.
- Promising a fixed response deadline.
- Confirming an incident before facts are known.
- Sharing internal logs or user data with the reporter.

## Escalation Rules

Escalate immediately to technical owner when:

- Production secret, token, key, or credential may be exposed.
- Unauthorized access to private user data is suspected.
- Authentication/session behavior is affected.
- Financial account connection data may be affected.
- Public forms are being abused.
- Backend, database, or vendor configuration may need action.

Escalate to privacy/legal/operator review when:

- User data exposure is suspected.
- A privacy/deletion request is part of the report.
- A regulator, attorney, platform, or financial institution is involved.
- Public notification may be required.
- Reporter asks for safe harbor, disclosure terms, or bounty.
- The report involves another person's data.

## Immediate Containment Options

Depending on the report, possible actions include:

- Disable affected public form.
- Rotate exposed key/credential.
- Remove exposed secret from public content.
- Disable compromised account/session if supported.
- Revoke or rotate provider token where applicable.
- Patch affected endpoint/page.
- Pause affected feature.
- Add monitoring or rate limiting.
- Contact affected user through verified channel.

Do not list these options publicly as guarantees. They are internal examples.

## Public Copy Boundaries

The landing site may say:

- Clarity has a published support path for security concerns.
- Users/reporters should provide non-sensitive details.
- Clarity reviews security and privacy-related messages.
- Response timing depends on request type, verification needs, and operational availability.

The landing site must not say unless verified and reviewed:

- `24/7 monitoring`
- `dedicated security team`
- `formal bug bounty`
- `safe harbor`
- `guaranteed response time`
- `guaranteed resolution`
- `formal incident SLA`
- `certified security program`

## Plaid-Friendly Wording

Use:

- `security concern`
- `suspected unauthorized access`
- `vulnerability report`
- `published support path`
- `non-sensitive reproduction steps`
- `do not send sensitive credentials`
- `monitored inbox`
- `internal escalation`

Avoid:

- `emergency security center`
- `bug bounty`
- `safe harbor`
- `guaranteed response`
- `24/7 security operations`
- `we can recover any account`
- `send us your login code`
- `share your bank password`

## Launch Review Questions

Before publishing `/contact` and `/security`, confirm:

- Is the security report path visible and monitored?
- Is there a security contact owner and backup?
- Are report categories and severity labels defined?
- Is there a tracker for security reports?
- Are escalation rules documented?
- Are sensitive-data warnings visible?
- Does the public page avoid bug bounty, safe harbor, and hard SLA promises?
- Are privacy/deletion overlaps routed to the privacy workflow?
- Can the team disable public forms or rotate credentials if needed?
- Are footer links and policy links consistent?

## Acceptance Checklist

- Public security report path is defined.
- Security owner and backup role are defined.
- Report categories are defined.
- Severity guide is defined.
- Tracking fields and statuses are defined.
- Triage workflow is defined.
- Reporter acknowledgement/follow-up copy is defined.
- Escalation rules are defined.
- Sensitive-data warnings are included.
- Public copy avoids unsupported security program claims.
