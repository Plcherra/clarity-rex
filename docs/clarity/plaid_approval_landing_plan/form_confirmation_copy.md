# Clarity Form Confirmation Copy

Status: File 07 Phase 7 confirmation copy approved for initial landing launch draft.

Purpose: centralize the public success, error, validation, and follow-up copy for Clarity waitlist/contact forms so the landing site feels polished without overpromising response times, approval, deletion, or security handling.

This contract supports:

- Waitlist form.
- Contact form.
- Privacy request submissions.
- Data deletion request submissions.
- Security concern submissions.

It aligns with:

- `contact_requirements.md`
- `waitlist_form_scope.md`
- `form_destination_plan.md`
- `data_deletion_page_contract.md`
- `privacy_request_workflow.md`
- `security_contact_workflow.md`

## Copy Goals

Form feedback should:

- Confirm what happened.
- Set a realistic expectation.
- Avoid promising instant response or approval.
- Avoid exposing provider/database/backend errors.
- Remind users not to send sensitive information where relevant.
- Give a fallback path if submission fails.
- Keep Clarity as the product name and Rex as the assistant inside Clarity.

## Global Success Pattern

Use this pattern for successful submissions:

> Thanks. We received your request and will review it through the published support path.

Optional expectation sentence:

> Response timing may depend on the request type, verification needs, and operational availability.

Avoid:

- `We will respond immediately`
- `Guaranteed response`
- `Your request is approved`
- `Your account has been deleted`
- `Your bank is connected`
- `Plaid approved your request`

## Waitlist Success Copy

Preferred:

> You're on the list. We'll contact you about Clarity beta access or product updates when there is a relevant next step.

Short version:

> You're on the list. Thanks for your interest in Clarity.

Optional follow-up:

> Please do not send bank credentials or sensitive financial details through public forms or email.

Avoid:

- `You are approved`
- `Guaranteed beta access`
- `Your invite is coming today`
- `Your Plaid access is ready`
- `Connect your bank now`

## General Contact Success Copy

Preferred:

> Thanks. We received your message and will review it through the published support path.

Optional follow-up:

> If your message involves privacy, data deletion, or security, we may need additional non-sensitive information to verify or respond to the request.

Short version:

> Message received. Thanks for contacting Clarity.

## Privacy Request Success Copy

Preferred:

> We received your privacy request. We may need to verify your identity or request scope before taking action.

Optional follow-up:

> Please do not send bank passwords, full account numbers, Social Security numbers, one-time login codes, or other sensitive secrets.

Avoid:

- `Your privacy request is complete`
- `No verification is needed`
- `We deleted everything`
- `All vendors deleted your data`

## Data Deletion Request Success Copy

Preferred:

> We received your deletion request. Clarity may need to verify your identity and review the request scope before completing deletion.

Optional follow-up:

> Disconnecting a financial account is different from deleting stored Clarity data. Some information may remain where retention is needed for legal, security, backup, vendor, or operational reasons.

Short version:

> Deletion request received. We may follow up to verify and process the request.

Avoid:

- `Your account has been deleted`
- `Everything was deleted instantly`
- `All backup and vendor data is gone`
- `Deletion is guaranteed within 24 hours`

## Security Concern Success Copy

Preferred:

> We received your security concern and will review the information provided through the published support path.

Optional follow-up:

> If safe to share, provide the affected page or feature and non-sensitive steps to reproduce. Do not send passwords, one-time codes, API keys, private keys, or sensitive user data.

Short version:

> Security concern received. Thanks for reporting it.

Avoid:

- `We confirm an incident occurred`
- `Guaranteed response time`
- `Bug bounty approved`
- `Safe harbor confirmed`
- `We will resolve this immediately`

## Validation Copy

Required field:

> Please complete this field.

Invalid email:

> Enter a valid email address.

Missing consent:

> Please confirm that Clarity may contact you about this request.

Message too long:

> Please shorten your message and try again.

Sensitive-data reminder:

> Do not include bank passwords, account numbers, card numbers, SSNs, one-time codes, API keys, screenshots, CSV files, or other sensitive financial details.

Avoid:

- Raw regex messages.
- Database constraint names.
- Provider validation names.
- Field labels that expose internal schemas.

## Error Copy

Generic error:

> We could not submit the form. Please check your information and try again.

Temporary outage:

> We could not submit the form right now. You can also contact Clarity through `/contact` or the published support email.

Spam/protection failure:

> We could not verify the submission. Please try again or use the published contact path.

Network error:

> The request could not be sent. Check your connection and try again.

Avoid:

- Raw database errors.
- API provider names.
- Stack traces.
- HTTP status codes as user-facing copy.
- Detailed anti-spam logic.
- Environment variable names.

## Email Auto-Reply Copy

If using an auto-reply, keep it general:

Subject:

> We received your Clarity request

Body:

> Thanks for contacting Clarity. We received your request and will review it through the published support path. Response timing may depend on the request type, verification needs, and operational availability.
>
> Please do not send bank passwords, full account numbers, full card numbers, Social Security numbers, one-time login codes, API keys, private keys, or other sensitive secrets through email or public forms.

Do not include:

- Internal ticket IDs unless the support workflow actually uses them.
- Response deadlines unless operationally supported.
- Legal conclusions.
- Security incident confirmations.

## UI Placement Guidance

Recommended:

- Inline success state near the form.
- Clear error state near the failed field or form top.
- Preserve the user's typed message after recoverable errors where safe.
- Disable duplicate submissions while sending.
- Make success/error copy readable on mobile.

Avoid:

- Toast-only confirmation for important privacy/deletion/security requests.
- Errors that disappear too quickly.
- Loading states with no final result.
- Confirmation language hidden below the fold.

## Plaid-Friendly Wording

Use:

- `request received`
- `published support path`
- `may need to verify`
- `request scope`
- `operational availability`
- `non-sensitive information`
- `Privacy Policy`
- `Data Deletion`

Avoid:

- `Plaid approved`
- `guaranteed`
- `instant`
- `bank support`
- `bank credentials`
- `upload statements`
- `automatic deletion`
- `bug bounty`
- `safe harbor`

## Launch Review Questions

Before implementation, confirm:

- Does each form type have success copy?
- Does each form type have error copy?
- Does validation copy avoid backend internals?
- Are privacy/deletion/security flows clear without overpromising?
- Is a fallback contact path shown on form failure?
- Are sensitive-data warnings visible before submission?
- Does mobile layout show confirmation clearly?
- Does copy avoid Plaid endorsement, approval, or support implications?

## Acceptance Checklist

- Waitlist success/error copy is defined.
- Contact success/error copy is defined.
- Privacy request success/error copy is defined.
- Data deletion success/error copy is defined.
- Security concern success/error copy is defined.
- Validation copy is defined.
- Fallback contact copy is defined.
- Copy avoids instant response, approval, deletion, and backend details.
- Sensitive-data reminder is included.
- UI placement guidance is included.
