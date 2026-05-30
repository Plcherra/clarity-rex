# Clarity Security Incident And Support Language

Status: File 06 Phase 7 incident and support language approved for initial landing launch draft.

Purpose: define public `/security` page language for reporting security concerns, account issues, privacy/deletion questions, and support needs without promising unsupported response times or exposing internal incident-handling details.

This contract supports the `/security` page section titled `Security contact`.

## Section Goal

The incident and support section should help users and Plaid reviewers understand:

- Clarity has a clear public path for security concerns.
- Users can report suspected unauthorized access, privacy concerns, deletion questions, and security issues.
- Users should not send sensitive credentials or secrets through public forms or email.
- Response expectations should be professional but not overpromised.
- Internal escalation and tracking should exist before launch.

This section should make Clarity feel reachable and responsible.

## Recommended Section Title

Preferred:

- `Security contact`

Acceptable alternatives:

- `Report a security concern`
- `Security and privacy support`
- `Need help with data or account security?`

Avoid:

- `Emergency response`
- `24/7 security operations`
- `Guaranteed response SLA`
- `Instant incident resolution`

## Plain-Language Summary

Recommended draft:

> If you believe your Clarity account, connected account data, privacy request, or security may be affected, contact Clarity through the published support path.

Recommended follow-up:

> Please do not send bank passwords, full account numbers, full card numbers, Social Security numbers, one-time login codes, API keys, or private secrets through public forms or email.

## Report Categories

The Contact page or support inbox should be able to route these categories:

- Suspected unauthorized account access.
- Trouble disconnecting a financial account.
- Data deletion or privacy request questions.
- Incorrect or unexpected connected-account behavior.
- Security vulnerability reports.
- Suspicious emails, phishing, impersonation, or abuse.
- Lost device or account-access concerns.
- Voice/chat privacy questions.
- General support.

For v1, this can be a simple reason dropdown, subject line convention, or clear contact instructions. It does not need a full ticketing system yet, but it must be monitored.

## Support Email Or Contact Path

Required before launch:

- Final support email or Contact page route.
- If a separate security email exists, publish it consistently.
- If one inbox handles support/privacy/security, explain that clearly.
- Footer, Privacy, Terms, Security, Data Deletion, and Contact pages must use the same contact path unless intentionally separated.

Recommended draft:

> Contact Clarity through `/contact` or the published support email.

Do not publish placeholders publicly.

## Response Expectation Language

Recommended copy:

> Clarity reviews security and privacy-related messages through the published support path. Response timing may depend on the nature of the request, verification needs, and operational availability.

Optional simpler copy:

> We review security and privacy-related messages and may ask for additional information to verify the request.

Avoid:

- `We respond immediately`
- `24/7 response`
- `We resolve all issues within 24 hours`
- `Guaranteed resolution`
- `We can recover any account`
- `We can reverse any provider issue`

Unless support operations are truly staffed and measured for that promise, do not publish hard timelines.

## Sensitive Information Warning

This warning should appear on `/security`, `/contact`, and `/data-deletion`:

> Do not send bank passwords, full account numbers, full card numbers, Social Security numbers, one-time login codes, API keys, private keys, or other sensitive secrets through public forms or email.

Optional follow-up:

> If Clarity needs additional verification, we will request the minimum information needed through the published support path.

## Vulnerability Report Guidance

Recommended copy:

> If you believe you found a vulnerability, include a short description, the affected page or feature, steps to reproduce if safe to share, and a contact email for follow-up. Do not include sensitive user data, secrets, or information from accounts you are not authorized to access.

Must convey:

- Responsible reporting is welcome.
- Do not test against accounts or data the reporter is not authorized to use.
- Do not exfiltrate, publish, or share sensitive data.
- Do not include secrets publicly.

Do not promise:

- Bug bounty rewards.
- Safe harbor language unless legally reviewed.
- Specific triage timelines.
- Public disclosure timelines.

## Account Security Support

Recommended copy:

> If you believe your Clarity account has been accessed without permission, contact Clarity through the published support path and include the email associated with your Clarity account, a short description of what happened, and any relevant non-sensitive details.

Must convey:

- Users should report suspected unauthorized access.
- Clarity may need to verify identity before acting.
- Users should also secure their device/email where relevant.

Do not ask for:

- Passwords.
- Bank credentials.
- One-time login codes.
- Full card/account numbers.
- SSNs.

## Public Copy Block

This block can be adapted directly for the `/security` page:

> To report a security concern, suspected unauthorized account access, privacy issue, or deletion question, contact Clarity through `/contact` or the published support email. Please include a clear description and enough non-sensitive detail for follow-up.

Optional second paragraph:

> Do not send bank passwords, full account numbers, full card numbers, Social Security numbers, one-time login codes, API keys, private keys, or other sensitive secrets through public forms or email.

Optional vulnerability report paragraph:

> If you believe you found a vulnerability, include the affected page or feature and safe reproduction steps if available. Do not access, copy, publish, or share data that you are not authorized to use.

## Internal Launch Requirements

Before publishing this section, Clarity should define:

- Who monitors the support/security inbox.
- How incoming security/privacy messages are tracked.
- How urgent reports are escalated.
- How identity verification is handled for account/deletion requests.
- How users receive confirmation or follow-up.
- How spam, abuse, or unsafe submissions are handled.
- What information support is allowed to request.

These internal details do not all need to appear publicly, but they need to exist.

## What Not To Expose

Do not include:

- Internal escalation names or personal phone numbers.
- Private incident runbooks.
- Admin console screenshots.
- Support inbox screenshots.
- Internal ticket IDs.
- Security tool names unless intentionally public.
- Vulnerability backlog details.
- Provider dashboard URLs.
- Secrets, tokens, API keys, or test credentials.

Allowed:

- Public support email or `/contact`.
- General report categories.
- Non-sensitive submission instructions.
- General response expectation language.

## Plaid-Friendly Wording

Use:

- `published support path`
- `security concern`
- `suspected unauthorized access`
- `privacy or deletion request`
- `verification may be required`
- `do not send sensitive credentials`
- `non-sensitive details`

Avoid:

- `instant response`
- `guaranteed resolution`
- `24/7 support`
- `we can fix any bank issue`
- `send us your login code`
- `share your bank password`
- `bug bounty` unless implemented and reviewed.

## Claims That Require Verification

Do not publish these without operational verification:

- Specific response-time SLAs.
- Dedicated security email.
- Dedicated security team.
- 24/7 monitoring.
- Bug bounty program.
- Safe harbor policy.
- Formal vulnerability disclosure policy.
- Specific identity-verification method.
- Specific incident notification timelines.

## Cross-Links

This section should link to:

- `/contact` for reporting security, privacy, account, or support concerns.
- `/data-deletion` for deletion request instructions.
- `/privacy` for privacy rights, vendor, and retention details.
- `/terms` for account responsibilities and acceptable use.

## Implementation Review Questions

Before publishing, verify:

- What is the final support/security contact path?
- Is there one inbox or separate support/privacy/security addresses?
- Who monitors incoming messages?
- How are security reports tracked?
- What identity verification is required for account/deletion requests?
- Does the Contact page warn users not to send sensitive credentials?
- Does the footer show the correct support path?
- Does this section avoid hard SLAs or unsupported support promises?

## Acceptance Checklist

- Provides security/support email or contact route.
- Explains users can report security concerns.
- Warns users not to send sensitive credentials or secrets.
- Does not promise unrealistic response times.
- Gives vulnerability reporters safe, minimal guidance.
- Aligns with Contact, Privacy, Terms, Data Deletion, and footer language.
- Flags operational support claims for verification before launch.
