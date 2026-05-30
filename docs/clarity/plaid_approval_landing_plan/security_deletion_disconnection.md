# Clarity Security Deletion And Disconnection

Status: File 06 Phase 6 deletion and disconnection section approved for initial landing launch draft.

Purpose: define public `/security` page language explaining how users can disconnect financial accounts and request deletion without promising unsupported automation, instant deletion, or removal from every backup/vendor system.

This contract supports the `/security` page section titled `Account disconnection and data deletion`.

## Section Goal

The deletion and disconnection section should help users and Plaid reviewers understand:

- Users can disconnect connected financial accounts where supported.
- Disconnecting an account is different from deleting stored Clarity data.
- Users can request deletion through the published Data Deletion path or support contact.
- Identity verification may be required.
- Deletion may be subject to legal, security, fraud-prevention, backup, vendor, and operational constraints.
- The public deletion process must match actual tooling and support workflow.

This section should be direct and confidence-building, not evasive.

## Recommended Section Title

Preferred:

- `Account disconnection and data deletion`

Acceptable alternatives:

- `Disconnecting accounts and deleting data`
- `Your account and data controls`
- `Deletion and connected account controls`

Avoid:

- `Instant deletion`
- `Delete everything automatically`
- `Disconnect to erase all history`
- `Remove all vendor records immediately`

## Plain-Language Summary

Recommended draft:

> Users can disconnect connected financial accounts where supported and can request deletion of Clarity account or product data through the published Data Deletion path or support contact.

Recommended follow-up:

> Disconnecting a financial account may stop future access through that connection, but it may not automatically delete historical data already stored in Clarity unless deletion is also requested.

## Disconnection Boundary

Recommended copy:

> Disconnecting a financial account is intended to stop future access through that connection where supported. It does not necessarily remove historical transactions, budgets, categories, dashboard summaries, Rex context, support records, or other data already stored in Clarity.

Must convey:

- Disconnection and deletion are different.
- Disconnection may be self-serve, support-driven, or both depending on implementation.
- Stored historical data may remain for product continuity unless deletion is requested.
- This must align with app behavior before publication.

Do not say:

- Disconnecting deletes all data.
- Disconnecting deletes every vendor-side record.
- Future access stops instantly unless verified.
- All institutions/providers support disconnection the same way.

## Deletion Request Boundary

Recommended copy:

> Users can request deletion of Clarity account or product data through `/data-deletion` or the published support contact. Clarity may need to verify identity and review the request scope before completing deletion.

Must convey:

- Deletion request path is public and easy to find.
- Identity verification may be required.
- Request scope matters: account deletion, financial data deletion, conversation deletion, memory/context deletion, support request deletion, etc.
- Confirmation/follow-up should go through the published contact path.

Do not say:

- Deletion is instant.
- No identity verification is needed.
- All backup/vendor copies are immediately removed.
- All legal/security logs are always removed.

## What Users Can Request

The public deletion page and security section should support requests related to:

- Clarity account deletion.
- Personal information deletion.
- Connected or imported financial account data deletion.
- Transaction history deletion.
- Budget, category, goal, and planning data deletion.
- Rex conversation/history deletion where supported.
- Approved memory/context deletion where supported.
- Voice transcripts, generated responses, or related metadata deletion where supported.
- Support/contact/waitlist record deletion where legally and operationally possible.

The actual form can stay simple, but the internal workflow should categorize requests clearly.

## Backup, Legal, Security, And Operational Limits

Recommended copy:

> Some information may remain for a limited period in backups, logs, security records, support records, or systems where retention is needed for legal, fraud-prevention, security, dispute-resolution, or operational reasons.

Must convey:

- Deletion may not instantly remove every copy everywhere.
- Backup/log constraints are normal and should be disclosed calmly.
- Any exact timelines require verification.
- This should align with Privacy Policy retention language.

## Vendor And Provider Considerations

Recommended copy:

> Some service providers may process or retain information according to their own terms, privacy policies, settings, or legal obligations. Clarity should describe vendor-side deletion only where the process is verified.

Relevant provider categories:

- Plaid/account connection provider.
- Authentication/database/storage provider.
- AI model provider.
- Speech-to-text provider.
- Text-to-speech provider.
- Contact/support/waitlist provider.
- Analytics/reliability provider if used.

Do not claim:

- Clarity can delete every vendor record instantly.
- Vendors never retain data.
- Vendor deletion workflows are automatic unless verified.

## Support Contact Requirements

The public Security page should direct users to:

- `/data-deletion` for deletion requests.
- `/contact` for account, privacy, or security questions.
- `[privacy/support email]` once finalized.

Support copy should say:

> Please do not send bank passwords, full account numbers, full card numbers, Social Security numbers, or one-time login codes through contact forms or email.

This must match:

- `privacy_user_rights_and_choices.md`
- `privacy_retention_and_deletion.md`
- `terms_eligibility_accounts.md`
- `07_waitlist_and_contact.md`

## Public Copy Block

This block can be adapted directly for the `/security` page:

> Users can disconnect connected financial accounts where supported and request deletion of Clarity account or product data through the published Data Deletion path or support contact. Disconnecting a financial account may stop future access through that connection, but it may not automatically delete historical data already stored in Clarity unless deletion is also requested.

Optional second paragraph:

> Clarity may need to verify your identity and review the request scope before completing deletion. Some information may remain for a limited period in backups, logs, security records, support records, or systems where retention is needed for legal, fraud-prevention, security, dispute-resolution, or operational reasons.

Optional contact note:

> Please do not send bank passwords, full account numbers, full card numbers, Social Security numbers, or one-time login codes through contact forms or email.

## What Not To Expose

Do not include:

- Internal deletion SQL.
- Auth admin screenshots.
- Provider dashboard screenshots.
- Plaid item/token IDs.
- User IDs.
- Internal support tickets.
- Raw deletion logs.
- Backup paths.
- Service-role operations.
- Private runbooks on production access.

Allowed:

- Public route names.
- Plain-language request flow.
- Provider categories.
- General backup/legal/security/operational constraints.

## Plaid-Friendly Wording

Use:

- `disconnect connected financial accounts`
- `stop future access through that connection`
- `request deletion`
- `published Data Deletion path`
- `identity verification`
- `historical data already stored in Clarity`
- `legal, security, backup, and operational limits`

Avoid:

- `delete everything instantly`
- `disconnect erases history`
- `remove all vendor records immediately`
- `Plaid deletes everything for us`
- `we never retain logs`
- `complete deletion guaranteed`

## Claims That Require Verification

Do not publish these without implementation and operations verification:

- Whether account disconnection is self-serve.
- Whether account deletion is self-serve.
- Whether deleting auth users cascades all user-owned records.
- Exact Plaid item/token removal behavior.
- Exact vendor deletion behavior.
- Exact raw-audio/transcript deletion behavior.
- Exact backup/log retention windows.
- Exact deletion completion timelines.
- Exact deletion confirmation workflow.
- Exact identity-verification process.

## Cross-Links

This section should link to:

- `/data-deletion` for deletion request instructions.
- `/privacy` for retention, vendor, and user-rights language.
- `/terms` for account responsibilities and service limitations.
- `/contact` for account, support, privacy, or security questions.

## Implementation Review Questions

Before publishing, verify:

- Is financial account disconnection self-serve, support-driven, or both?
- What happens to Plaid items/tokens on disconnect?
- What happens to stored historical transactions after disconnect?
- Is account deletion self-serve, support-driven, or both?
- Which database rows are deleted when account deletion is processed?
- Are conversations, memory/context, voice transcripts, and support records included in deletion scope?
- What backup/log retention constraints apply?
- What support inbox or form receives deletion requests?
- What confirmation/follow-up message is sent?

## Acceptance Checklist

- Explains users can disconnect financial accounts where supported.
- Explains users can request deletion.
- Provides support/contact path.
- Clearly distinguishes disconnection from deletion.
- Avoids instant deletion, complete vendor deletion, and unsupported automation claims.
- Links to `/data-deletion`, Privacy, Terms, and Contact.
- Flags implementation-dependent deletion behavior for verification before launch.
