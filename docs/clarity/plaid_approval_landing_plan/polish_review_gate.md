# Polish Review Gate

Status: File 09 Phase 8 review gate complete. The former Privacy, Terms, and Security placeholder blockers have been resolved; the remaining production-only blocker is live FormSubmit activation and delivery testing after deployment.

## Scope

This gate consolidates the File 09 polish checks before the final deployment plan begins.

Checked areas:

- Responsive layout.
- Accessibility structure.
- SEO metadata.
- Sitemap and robots.txt.
- Performance and static asset weight.
- Internal links.
- Form wiring.
- Public copy consistency.
- Placeholder and draft-copy scan.

## Passed Checks

The current static site passes these polish checks:

- Product naming uses Clarity as the product and Rex as the assistant.
- Public Plaid language is conservative and does not claim Plaid endorsement, certification, approval, or partnership.
- Public copy does not claim guaranteed outcomes, perfect categorization, or real-time bank updates.
- Public source pages do not expose backend/VPS/internal-secret language.
- Sitemap and robots.txt are generated.
- Canonical and social metadata use `https://goclarity.app`.
- The social image is synthetic and contains no personal financial data.
- Link scan found no unknown local public links.
- Waitlist and contact forms are wired to `https://formsubmit.co/clarity.rex@gmail.com`.
- Release build passes.
- NPM audit reports zero vulnerabilities.

## Resolved Public Page Blockers

The following former launch blockers were resolved before starting File 10:

1. Replace draft Privacy page copy.
   - Current file: `apps/web/src/pages/privacy.astro`
   - Status: resolved with public privacy copy covering account/profile data, connected financial context, Rex assistant data, Plaid/account-connection language, vendor sharing, retention, deletion, choices, and security links.

2. Replace draft Terms page copy.
   - Current file: `apps/web/src/pages/terms.astro`
   - Status: resolved with public terms copy covering product boundaries, eligibility, account connections, AI/financial advice limitations, acceptable use, availability, changes, and support links.

3. Replace draft Security page copy.
   - Current file: `apps/web/src/pages/security.astro`
   - Status: resolved with public security copy covering user-authorized data flow, access controls, secure transport patterns, vendors, voice handling, deletion/disconnection, and security contact.

## Remaining Production Blocker

The following item must be completed after deployment and before Plaid review:

1. Perform live FormSubmit activation and delivery testing after deployment.
   - Destination: `clarity.rex@gmail.com`
   - Required test: submit safe waitlist/contact messages from the live site, confirm inbox/spam delivery, confirm any FormSubmit activation email, and verify the success redirect.

## Deployment Readiness Decision

File 09 polish is structurally complete. The site may proceed into File 10 final review and deployment planning.

File 10 must still handle final content freeze, legal review status, production deployment, live route checks, and live FormSubmit testing.

## Verification Commands

Run these commands again after the legal/security pages are replaced:

```bash
./scripts/web_release_build.sh
rg -n "Draft .*content|TODO|FIXME|\\[[^\\]]+\\]" apps/web/src/pages apps/web/src/components apps/web/public
```

## Acceptance Decision

File 09 Phase 8 passes as a review gate. Proceed to File 10 with FormSubmit live delivery testing preserved as a required post-deploy manual check.
