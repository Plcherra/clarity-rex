# Clarity Security Access Controls

Status: File 06 Phase 3 access control story approved for initial landing launch draft.

Purpose: define public `/security` page language explaining who can access user data and under what boundaries, without claiming unverified controls or exposing implementation details.

This contract supports the `/security` page section titled `Access controls`.

## Section Goal

The access-control section should help users and Plaid reviewers understand:

- Users access Clarity through authenticated accounts.
- Product data should be scoped to the signed-in user.
- Internal/admin access should be limited to people and purposes that require it.
- Support access should be purpose-bound and not ask users to send bank credentials.
- Users are responsible for keeping their account credentials and devices secure.

The section should be plain and credible. It should avoid dense security jargon unless a claim is verified and easy to explain.

## Recommended Section Title

Preferred:

- `Access controls`

Acceptable alternatives:

- `Who can access your Clarity data`
- `How access is limited`
- `Account and support access`

Avoid:

- `Zero-trust architecture`
- `Military-grade access control`
- `Guaranteed privacy controls`
- `Internal RBAC implementation`

## Plain-Language Summary

Recommended draft:

> Clarity is designed so users access their own product data through authenticated accounts. Internal access should be limited to authorized operational, support, security, or compliance purposes. Public support paths should not ask users to send bank passwords, account numbers, full card numbers, or Social Security numbers.

Optional follow-up:

> Access-control details may evolve as Clarity grows. Public claims should describe verified practices, not planned controls.

## User Authentication

Recommended copy:

> Users access Clarity through account authentication. Users are responsible for keeping their account credentials and devices secure and should contact Clarity if they believe their account has been accessed without permission.

Must convey:

- Users sign in before seeing private app data.
- Users should use an email/account they control.
- Users should report suspected unauthorized access.
- Public contact forms and email should not be used to send sensitive bank credentials.

Do not publish unless verified:

- Exact authentication method names.
- MFA support.
- Passwordless-only claims.
- Session timeout periods.
- Device-trust or biometric requirements.

## User-Scoped Product Data

Recommended copy:

> Clarity should scope account, transaction, budget, conversation, memory/context, and related product data to the authenticated user who owns or is authorized to use that data.

Must convey:

- Users should not be able to inspect another user's private product data.
- Connected account data belongs to the user/account that authorized the connection.
- Product data includes financial context and Rex-related context.

Implementation verification required:

- Confirm row-level or equivalent user-scoped access protections before publishing any specific technical claim.
- Confirm support/admin tooling does not bypass user boundaries except through purpose-bound operational access.

## Internal And Administrative Access

Recommended copy:

> Clarity should limit internal access to user data to authorized purposes such as operating the service, troubleshooting, security, compliance, support, and responding to user requests.

Must convey:

- Internal access is not for casual browsing.
- Admin or operator access should be limited and purpose-bound.
- Access should be reduced as the product matures.

Do not publish unless verified:

- Formal role-based access control details.
- Named internal tools.
- Audit-log coverage.
- Employee background checks.
- Mandatory training programs.
- SOC 2-style access review processes.

## Support Access

Recommended copy:

> If you contact Clarity for support, privacy, deletion, or security help, support may use the information you provide and limited account context needed to respond. Support should not ask for bank passwords, full account numbers, full card numbers, Social Security numbers, or one-time login codes.

Must convey:

- Support access is tied to the request.
- Users should avoid sending sensitive financial credentials.
- Support cannot guarantee that every bank/provider issue can be resolved by Clarity.

Links:

- `/contact`
- `/data-deletion`
- `/privacy`

## Service Provider Access

Recommended copy:

> Clarity uses service providers to help operate the product. These providers may process information to provide hosting, authentication, account connection, AI, speech, text-to-speech, support, security, analytics, or reliability services as described in the Privacy Policy.

Must convey:

- Providers process data to provide Clarity.
- Provider access depends on the service they deliver.
- Vendor processing should align with Privacy Policy disclosures.

Do not claim:

- Vendors never process data.
- Vendors never retain data.
- Vendors are all certified to a specific standard unless verified.
- Clarity controls every third-party privacy practice.

## User Responsibilities

Recommended copy:

> Users should keep their Clarity account, device, email, and connected-account permissions secure. Users should connect only accounts they own or are authorized to use with Clarity.

This should align with:

- `terms_eligibility_accounts.md`
- `terms_plaid_connection.md`
- `terms_acceptable_use.md`

Practical user guidance:

- Use an email address you control.
- Keep device access secure.
- Contact Clarity about suspicious activity.
- Do not share bank credentials through email or public forms.
- Disconnect accounts or request deletion through the published paths when needed.

## Public Copy Block

This block can be adapted directly for the `/security` page:

> Clarity is designed around authenticated user accounts and purpose-bound access. Users should be able to view their own Clarity product data after signing in. Internal access should be limited to operational, support, security, compliance, or user-requested purposes. If you contact support, please do not send bank passwords, full account numbers, full card numbers, Social Security numbers, or one-time login codes.

Optional second paragraph:

> Clarity also uses service providers to operate the product. Provider processing is described in the Privacy Policy and should be limited to the services they provide, such as hosting, account connection, AI assistance, speech processing, support, or reliability.

## What Not To Expose

Do not include:

- Database policy names.
- Admin console screenshots.
- Internal user IDs.
- Supabase project IDs.
- Service-role keys or descriptions.
- Raw access logs.
- Support inbox screenshots.
- Internal incident notes.
- Exact admin account names.
- IP allowlist details.
- Private implementation diagrams.

Allowed:

- `authenticated accounts`
- `user-scoped product data`
- `authorized operational access`
- `limited support access`
- `service providers`
- `purpose-bound access`

## Plaid-Friendly Wording

Use:

- `authenticated user accounts`
- `user-authorized account connections`
- `limited internal access`
- `purpose-bound support access`
- `service providers`
- `Privacy Policy`
- `Data Deletion`

Avoid:

- `anyone on our team can see your data`
- `we never access any data`
- `support has unlimited access`
- `Plaid controls Clarity access`
- `bank-grade admin security`
- `certified access controls` unless verified.

## Claims That Require Verification

Do not publish these without implementation and operations verification:

- Multi-factor authentication support.
- Specific session timeout periods.
- Specific role-based access control implementation.
- Admin audit logs.
- Automated access reviews.
- Employee training or background checks.
- Production access approval workflows.
- Security monitoring coverage.
- Exact support identity-verification process.

If these controls are planned but not live, keep them out of public copy or label them as future/internal roadmap outside the public landing site.

## Cross-Links

This section should link to:

- `/privacy` for vendor and data-use details.
- `/terms` for user account responsibilities and acceptable use.
- `/data-deletion` for account/data deletion requests.
- `/contact` for account, support, privacy, or security help.

## Implementation Review Questions

Before publishing, verify:

- Does authentication behavior match the live app?
- Are account, transaction, budget, conversation, memory, and goal records user-scoped?
- What admin/support access exists today?
- Does support have a real process for suspicious account activity?
- Does public copy avoid claiming MFA, audit logs, or formal RBAC unless implemented?
- Does the support-contact language match the Contact page?
- Does this section align with Privacy and Terms?

## Acceptance Checklist

- Explains user authentication.
- Explains user-scoped product data in plain language.
- Explains least-privilege/admin access as a principle without overclaiming.
- Explains support access is limited and purpose-bound.
- Tells users not to send sensitive credentials through support paths.
- Links to Privacy, Terms, Data Deletion, and Contact.
- Flags implementation-dependent access-control claims for verification before launch.
