# Copy Consistency Pass

Status: File 09 Phase 7 copy consistency pass complete with launch blockers noted.

## Scope

This pass checks the implemented public site copy for product-name drift, unsupported Plaid language, overclaims, internal implementation leakage, and user-facing draft copy.

## Product Naming

Approved naming:

- Product: `Clarity`
- Assistant: `Rex`
- Public domain: `goclarity.app`

The launch domain is `goclarity.app`, and public copy should continue to make clear that the product name is Clarity and Rex is the assistant inside Clarity.

## Copy Checks Passed

The implemented public site does not contain:

- Unsupported Plaid approval, certification, endorsement, partnership, or production-access claims.
- Claims that Plaid has approved Clarity.
- Claims that Clarity is a bank, broker, lender, tax advisor, or financial advisor.
- Claims that Rex directly connects to banks outside Clarity's user-authorized account connection flow.
- Claims that Clarity guarantees savings, approval, security, categorization, transcription, uptime, deletion, or outcomes.
- Claims that connected account data is always real-time or complete.
- Public backend secrets, API keys, local URLs, service-role language, VPS internals, or deployment internals.

## Copy Checks Requiring Phase 8 Action

The following public pages still contain draft placeholder copy and are not ready for launch:

- `apps/web/src/pages/privacy.astro`
- `apps/web/src/pages/terms.astro`
- `apps/web/src/pages/security.astro`

Required action before public launch:

- Replace draft Privacy copy with the approved privacy-policy content.
- Replace draft Terms copy with the approved terms content.
- Replace draft Security copy with the approved security/data-handling content.
- Re-run responsive, accessibility, metadata, link, and copy checks after those pages are filled.

## Form Delivery Note

The static QA confirms that forms are wired to `https://formsubmit.co/clarity.rex@gmail.com`, but it does not prove delivery.

Before launch, complete a real FormSubmit activation/test:

- Submit a safe test message with no sensitive data.
- Check `clarity.rex@gmail.com` inbox and spam.
- Confirm the FormSubmit activation email if prompted.
- Verify the user is redirected to `https://goclarity.app/form-success`.

## Verification Commands

- Public source copy scan.
- Generated HTML link/form scan from Phase 6.
- `./scripts/web_release_build.sh`

## Acceptance Decision

File 09 Phase 7 passes for consistency. File 09 Phase 8 must treat the draft Privacy, Terms, and Security pages plus FormSubmit delivery activation as launch blockers.
