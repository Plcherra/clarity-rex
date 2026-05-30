# Clarity Contact Review Gate

Status: File 07 Phase 8 contact review gate approved for initial landing launch draft.

Purpose: define the final QA gate for Clarity waitlist, contact, privacy, data deletion, and security contact paths before the public landing site is deployed or used for Plaid review.

This gate consolidates:

- `contact_requirements.md`
- `waitlist_form_scope.md`
- `form_destination_plan.md`
- `data_deletion_page_contract.md`
- `privacy_request_workflow.md`
- `security_contact_workflow.md`
- `form_confirmation_copy.md`

## Gate Goal

Before launch, every public contact path must be real, monitored, privacy-conscious, and consistent with the Privacy Policy, Terms, Security page, Data Deletion page, footer, and Plaid-facing product story.

The landing site should prove:

- Users can contact Clarity.
- Users can request beta access.
- Users can submit privacy and deletion requests.
- Users can report security concerns.
- Forms avoid collecting unnecessary sensitive data.
- Confirmation/error states are professional.
- Submissions are delivered to a monitored destination.

## Required Public Routes

Verify these routes exist and render on desktop and mobile:

- `/contact`
- `/data-deletion`
- `/privacy`
- `/terms`
- `/security`

Required footer links:

- `Contact`
- `Data Deletion`
- `Privacy`
- `Terms`
- `Security`

Optional but recommended:

- Home page waitlist section or waitlist CTA.
- FAQ link to Contact/Data Deletion where appropriate.

## Contact Page Checklist

The `/contact` page must include:

- Published support email or working form path.
- Reason/category selector or clear category guidance.
- Categories for beta access, product support, privacy request, data deletion, security concern, and other.
- Sensitive-data warning before submission.
- Links to Privacy, Terms, Security, and Data Deletion.
- Response expectation that avoids hard timelines.

The page must not:

- Ask for bank passwords.
- Ask for full account numbers.
- Ask for card numbers.
- Ask for Social Security numbers.
- Ask for one-time login codes.
- Ask for Plaid tokens.
- Ask for CSV uploads or screenshots.
- Claim instant response or guaranteed resolution.

## Waitlist Checklist

The waitlist form must include only:

- Name.
- Email.
- Optional note.
- Consent checkbox.

Required:

- Consent copy explains follow-up communications.
- Sensitive-data warning is visible.
- Privacy and Terms links are available.
- Success and error states use approved copy.
- Submission destination is defined.
- Spam protection is active or documented for launch.

The waitlist must not imply:

- Plaid approval.
- Guaranteed beta access.
- Immediate invite.
- Bank connection readiness.
- Financial eligibility screening.

## Form Destination Checklist

Before launch, verify:

- Submission destination is selected.
- Submissions reach a monitored inbox, provider dashboard, or access-controlled table.
- Public users cannot read submissions if a database is used.
- Public submissions do not write into mobile product financial tables or assistant memory tables.
- Spam protection is active.
- Required fields validate client-side and server-side/provider-side.
- Message length limits are enforced.
- Success state appears after a valid submission.
- Error state appears when a submission fails.
- Raw provider/database errors are never user-facing.

## Privacy And Deletion Checklist

Verify:

- `/data-deletion` explains how to request deletion.
- `/data-deletion` links to `/contact` or the published support path.
- Identity verification may be required.
- Disconnection and deletion are clearly separated.
- Legal, security, fraud-prevention, backup, vendor, and operational limits are explained.
- Privacy Policy links to `/data-deletion`.
- Contact page includes `Privacy request` and `Data deletion` categories.
- Internal privacy request tracker/workflow exists.

Must not promise:

- Instant deletion.
- Deletion without verification.
- Deletion from every backup/vendor record.
- Exact timelines unless legally reviewed and operationally supported.

## Security Contact Checklist

Verify:

- `/contact` or `/security` provides a visible security report path.
- `Security concern` category exists or security contact instructions are clear.
- Security owner and backup role are defined internally.
- Report categories and severity labels are defined.
- Security tracker or inbox label workflow exists.
- Escalation rules are documented.
- Reporter acknowledgement copy is ready.
- Sensitive-data warning is visible.

Must not claim:

- 24/7 monitoring.
- Dedicated security team.
- Bug bounty.
- Safe harbor.
- Guaranteed response time.
- Guaranteed resolution.
- Certified security program.

## Confirmation Copy Checklist

Verify approved copy exists for:

- Waitlist success.
- General contact success.
- Privacy request success.
- Data deletion request success.
- Security concern success.
- Required-field validation.
- Invalid email.
- Missing consent.
- Message too long.
- Generic error.
- Temporary outage/fallback.
- Spam/protection failure.

Confirm:

- Success states do not disappear too quickly.
- Important privacy/deletion/security confirmations are not toast-only.
- Errors preserve user-entered content where safe.
- Backend/provider details are not exposed.

## Smoke Test Matrix

Run before deployment and again after deployment:

1. Valid waitlist submission.
2. Waitlist missing name.
3. Waitlist invalid email.
4. Waitlist missing consent.
5. Waitlist optional note over max length.
6. Valid general contact submission.
7. Valid privacy request submission.
8. Valid data deletion request submission.
9. Valid security concern submission.
10. Honeypot/spam path if available.
11. Simulated submission failure or disabled destination.
12. Footer link click-through on mobile.
13. Footer link click-through on desktop.
14. Privacy, Terms, Security, Contact, and Data Deletion cross-links.

For each successful submission, verify:

- User sees confirmation.
- Destination receives the submission.
- Submission category is clear.
- No sensitive data was requested.
- Test submission is distinguishable from real submissions.

## Accessibility And Mobile Checks

Verify:

- Forms are usable with keyboard navigation.
- Labels are visible and associated with fields.
- Error messages are readable by assistive technology where supported.
- Tap targets are comfortable on mobile.
- Consent checkbox is easy to tap.
- Confirmation/error copy is visible without awkward scrolling.
- Layout works on small mobile, large mobile, tablet, and desktop widths.

## Plaid Review Alignment

Before using the site for Plaid review, confirm:

- Product is called `Clarity`.
- Rex is described only as the AI assistant inside Clarity.
- Plaid is described as a service provider for user-authorized account connections.
- No copy implies Plaid endorsement, sponsorship, certification, or approval.
- Contact/waitlist forms do not ask for financial account credentials.
- Privacy, Terms, Security, Data Deletion, and Contact are all accessible from the footer.
- Data-use language matches Privacy and Security plans.

## Launch Blockers

Do not launch or submit to Plaid review if:

- Contact path is not monitored.
- Form destination is undefined.
- Test submissions do not arrive.
- Spam protection is absent and no manual mitigation is defined.
- Footer links are broken.
- Privacy/Terms/Security/Data Deletion links are missing.
- Public forms ask for sensitive financial details.
- Raw backend errors appear in the UI.
- Placeholder emails, company names, or unresolved launch-note markers remain.
- Any page promises instant deletion, guaranteed response, Plaid approval, or unsupported security claims.

## Acceptance Checklist

- Contact route is defined and linked.
- Data Deletion route is defined and linked.
- Waitlist/contact fields match approved scope.
- Submission destination is defined.
- Spam protection is defined and tested.
- Success and error states are defined and tested.
- Privacy request workflow is defined.
- Security contact workflow is defined.
- Footer and policy links point to contact/deletion pages.
- Test submissions work before deployment and after deployment.
- No sensitive financial details are requested.
- No unsupported Plaid, deletion, response-time, or security claims appear publicly.
