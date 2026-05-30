# Clarity Waitlist Form Scope

Status: File 07 Phase 2 waitlist form scope approved for initial landing launch draft.

Purpose: define the smallest safe waitlist form Clarity should publish for early access and Plaid review readiness.

This contract supports the home page waitlist CTA, `/contact` page, and any dedicated waitlist section or component.

## Section Goal

The waitlist form should let interested users request updates or beta access without collecting bank credentials, financial records, account details, or sensitive identity information.

The initial form should be intentionally small:

- Easy to complete on mobile.
- Easy to review for Plaid and privacy alignment.
- Low-risk from a data collection perspective.
- Compatible with a simple backend/form provider in Phase 3.

## Recommended Placement

Primary placement:

- Home page CTA section or inline waitlist block.

Secondary placement:

- `/contact` page under `Beta access`.

Optional later placement:

- Footer CTA.
- Product update page.
- Private beta invite page.

Avoid placing the form inside Privacy, Terms, Security, or Data Deletion pages. Those pages should link to `/contact` instead.

## Required Fields

The initial waitlist form should collect only:

1. `Name`
   - Label: `Name`
   - Required: yes
   - Purpose: personalize follow-up.

2. `Email`
   - Label: `Email`
   - Required: yes
   - Purpose: send waitlist, beta, or product updates.

3. `Note`
   - Label: `What are you hoping Clarity helps with?`
   - Required: no
   - Purpose: understand interest and support prioritization.

4. `Consent`
   - Label: consent checkbox.
   - Required: yes.
   - Purpose: confirm follow-up permission.

Recommended consent copy:

> I agree that Clarity may contact me about beta access, product updates, and my request. I understand I should not include bank credentials or sensitive financial details in this form.

Shorter acceptable copy:

> I agree Clarity may contact me about beta access and product updates.

If using the shorter version, keep a separate sensitive-data warning visible above the form.

## Optional Fields To Defer

Do not include these in the first public version unless there is a specific reason:

- Company.
- Phone number.
- Location.
- Connected bank/institution name.
- Monthly income.
- Spending amount.
- Account balance.
- Uploads.
- Budget files.
- CSV files.
- Screenshots.
- Plaid institution identifiers.

Reason: these fields increase privacy/compliance surface without being necessary for a public Plaid-ready landing page.

## Sensitive Data Warning

The waitlist form must include this warning near the note field:

> Please do not include bank passwords, account numbers, card numbers, Social Security numbers, one-time login codes, API keys, screenshots, CSV files, or other sensitive financial details.

If space is tight on mobile, use:

> Do not include bank credentials, account numbers, SSNs, or sensitive financial details.

## Field Validation

Minimum validation:

- `Name` is not empty.
- `Email` is a valid-looking email address.
- `Consent` is checked.
- `Note` has a reasonable max length.

Recommended max lengths:

- Name: 120 characters.
- Email: 254 characters.
- Note: 1,000 characters.

Do not reject users based on financial eligibility, account type, income, bank, credit score, or protected characteristics.

## Success State

Recommended success copy:

> You're on the list. We'll contact you about Clarity beta access or product updates when there is a relevant next step.

Optional warmer copy:

> You're on the list. Thanks for your interest in Clarity.

Avoid:

- `You are approved`
- `Your bank is connected`
- `Your Plaid access is ready`
- `You will receive an invite today`
- `Guaranteed beta access`

## Error State

Recommended error copy:

> We could not submit the form. Please check your information and try again.

If the form destination is unavailable:

> We could not submit the form right now. You can also contact Clarity through `/contact`.

Avoid:

- Raw database errors.
- API provider names.
- Stack traces.
- Validation messages that expose backend internals.

## Privacy Link And Consent Support

The waitlist form should link to:

- `/privacy`
- `/terms`

Recommended nearby copy:

> By submitting, you agree that Clarity may use your information to respond to your request and send relevant product updates. See the Privacy Policy for details.

This copy must align with:

- `privacy_policy_scope.md`
- `privacy_data_categories.md`
- `privacy_purpose_of_processing.md`
- `privacy_user_rights_and_choices.md`
- `contact_requirements.md`

## Plaid-Friendly Wording

Use:

- `Join the waitlist`
- `Request beta access`
- `Get product updates`
- `Clarity may contact me`
- `Do not include sensitive financial details`
- `Privacy Policy`

Avoid:

- `Connect your bank now`
- `Submit bank details`
- `Send statements`
- `Plaid approval waitlist`
- `Guaranteed access`
- `Approved user`
- `Financial eligibility`
- `Upload transactions`

## Launch Review Questions

Before publishing the waitlist form, confirm:

- Are only name, email, optional note, and consent collected?
- Is the sensitive-data warning visible on mobile and desktop?
- Does the consent copy explain follow-up communications?
- Are Privacy and Terms links present?
- Does the form avoid bank credentials, account numbers, CSV uploads, and screenshots?
- Are success and error states defined?
- Is spam protection or manual moderation planned in Phase 3?
- Does copy avoid implying Plaid endorsement or product approval?
- Does the form work without turning the site into a logged-in web app?

## Acceptance Checklist

- Waitlist fields are name, email, optional note, and consent checkbox.
- Consent explains follow-up communications.
- Sensitive-data warning is visible.
- No bank credentials or financial data are requested.
- Privacy and Terms links are present.
- Success and error copy are defined.
- Mobile form remains short and easy to complete.
- Language is Plaid-friendly and does not imply approval, endorsement, or guaranteed access.
