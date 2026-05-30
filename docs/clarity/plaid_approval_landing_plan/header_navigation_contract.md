# Clarity Landing Header Navigation Contract

Status: Phase 3 header/navigation contract approved for initial landing launch.

Purpose: define a minimal, trustworthy public header that helps Plaid reviewers and users reach the most important compliance pages without making the site feel like a full web app.

## Header Content

Desktop header:

- Left: Clarity logo mark or wordmark, linking to `/`.
- Center/right nav links:
  - Privacy -> `/privacy`
  - Security -> `/security`
  - Contact -> `/contact`
- Primary CTA:
  - Request access -> `/#request-access` or equivalent home form anchor.

Mobile header:

- Left: Clarity logo/name, linking to `/`.
- Right: Request access button if space allows.
- Overflow/menu:
  - Privacy
  - Security
  - Contact
  - Terms
  - Data Deletion

## Navigation Rules

- Keep header navigation short.
- Footer owns the complete compliance route list.
- Header must not duplicate every footer link on desktop if that makes the top bar busy.
- Rex should not appear as the header brand; Rex can appear in page copy as "the AI assistant inside Clarity."

## CTA Rules

Primary CTA label:

- Preferred: `Request access`
- Acceptable: `Join beta`

CTA target:

- Home page request-access/waitlist form anchor.

CTA copy constraints:

- Do not say "Connect bank" in the header for v1.
- Do not launch Plaid Link from the public header for v1.
- Do not imply instant access to production bank connections.

## Accessibility Requirements

- Header logo/name has accessible text: `Clarity home`.
- Mobile menu button has accessible label: `Open navigation`.
- Active route should be visually identifiable where practical.
- Keyboard users can reach all header links and the mobile menu.

## Mobile Layout Requirements

- Header must fit common mobile widths without wrapping the product name awkwardly.
- If the CTA and nav cannot fit, collapse links into a menu before shrinking text too far.
- Header should not overlap device safe areas.
- Sticky header is optional; if sticky, it must not cover anchor targets.

## Header Non-Goals For V1

- No authenticated app/dashboard link.
- No Plaid Link launch action.
- No pricing link unless pricing is real and approved.
- No blog/resources nav.
- No Rex-branded top-level navigation item.

## Review Checklist

- Header includes Clarity logo/name.
- Header includes Privacy, Security, Contact, and primary CTA.
- Mobile navigation exposes Terms and Data Deletion through menu or footer.
- Header language does not imply Plaid endorsement.
- Header does not ask users for sensitive data.
