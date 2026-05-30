# Public Legal And Security Pages Implementation

Status: Complete before File 10.

## Scope

The public Privacy, Terms, and Security routes were converted from placeholder pages into product-specific public copy for the Clarity landing site.

Updated pages:

- `apps/web/src/pages/privacy.astro`
- `apps/web/src/pages/terms.astro`
- `apps/web/src/pages/security.astro`

## Privacy Page Coverage

The Privacy page now covers:

- Clarity product identity and Rex assistant boundary.
- Account/profile data.
- Connected/imported financial context.
- Rex assistant data.
- User-authorized account connections through providers such as Plaid.
- No bank credential storage claim.
- Product, support, safety, and improvement purposes.
- Service provider categories.
- No sale of personal financial data.
- User choices, data deletion, disconnection, retention limits, and support contact.
- Security and sensitive-data warnings.

## Terms Page Coverage

The Terms page now covers:

- Service scope.
- Eligibility, personal use, and account security.
- Rex/AI assistant boundaries.
- Financial advice limitations.
- User-authorized account-connection provider dependencies.
- No guarantees of continuous access, immediate balance updates, exhaustive transaction coverage, or error-free categorization.
- Acceptable use.
- Availability, changes, warranty-style limitations, and support contact.

## Security Page Coverage

The Security page now covers:

- User-authorized data flow.
- Plaid/account-connection boundaries.
- Rex does not independently access banks or execute financial actions.
- User-scoped data and limited operational access.
- Public form safety.
- Secure transport and managed-provider language.
- Vendor categories.
- Voice is user-initiated and not always listening.
- Deletion/disconnection distinction.
- Security contact path and sensitive-data warnings.

## Verification

Commands run:

```bash
rg -n "Draft .*content|TODO|FIXME|\\[[^\\]]+\\]" apps/web/src/pages apps/web/src/components apps/web/public
rg -n "Plaid-approved|Plaid-backed|Plaid-certified|partnered with Plaid|bank-grade|military-grade|guaranteed secure|100% private|unhackable|zero-knowledge|end-to-end encrypted|SOC 2|ISO 27001|PCI compliant|HIPAA|always connected|real-time balances|complete transaction history|perfect categorization|perfect AI|perfect transcription|instant deletion|Rex connects to your bank|Rex manages your money" apps/web/src/pages apps/web/src/components apps/web/public
./scripts/web_release_build.sh
git diff --check -- apps/web/src/pages/privacy.astro apps/web/src/pages/terms.astro apps/web/src/pages/security.astro
```

Results:

- No user-facing draft legal/security placeholder text remains.
- No forbidden public-claim phrases were found in page/component/public copy.
- Release build passed.
- NPM audit reported zero vulnerabilities.
- Diff whitespace check passed.

## Remaining Manual Check

FormSubmit delivery cannot be fully verified until the site is deployed to `https://goclarity.app`.

After deployment:

- Submit one safe waitlist test.
- Submit one safe contact test.
- Check `clarity.rex@gmail.com` inbox and spam.
- Confirm any FormSubmit activation email if prompted.
- Verify redirect to `https://goclarity.app/form-success`.
