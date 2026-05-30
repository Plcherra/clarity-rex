# Clarity Plaid Landing Launch Scope Lock

Status: Phase 8 launch scope lock approved for initial landing launch.

Purpose: protect the Plaid approval landing project from expanding into a full web app before the public trust, privacy, security, and support surface is live.

## V1 Launch Objective

The v1 public site exists to help users and Plaid reviewers understand:

- What Clarity is.
- Who Rex is inside Clarity.
- Why Clarity uses financial account data.
- How account connection works at a high level.
- How users can review Privacy, Terms, Security, Data Deletion, and Contact paths.
- How interested users can request access or contact support.

The v1 public site is not intended to replace the mobile app.

## V1 Included Scope

The first public launch includes these routes:

- `/`
- `/privacy`
- `/terms`
- `/security`
- `/data-deletion`
- `/contact`

The first public launch includes these capabilities:

- Product landing page.
- Request access or contact CTA.
- Privacy Policy.
- Terms of Service.
- Security and data handling page.
- Data deletion instructions.
- Contact/support path.
- Mobile-friendly public layout.
- Plaid/data consent explanation.
- Synthetic or redacted screenshots only.

## V1 Explicit Non-Goals

Do not include these in v1:

- Authenticated web dashboard.
- Browser-based transaction management.
- Browser-based budget editing.
- Browser-based Rex chat.
- Browser-based Rex voice.
- Plaid Link launch from the public landing page.
- Bank connection onboarding from the public landing page.
- Payment collection.
- Pricing page, unless pricing is already final and legally reviewed.
- User settings or account management.
- Admin portal.
- Investor, press, or hiring pages.

## Plaid Link Boundary

The public site may explain that Clarity uses Plaid to help users connect accounts.

The public site must not:

- Start Plaid Link.
- Present itself as a live bank connection flow.
- Ask users for bank credentials.
- Collect account numbers, routing numbers, SSNs, or card numbers.

Plaid Link integration belongs inside the authenticated product experience after the compliance surface is ready and reviewed.

## Future Web App Backlog

These ideas are valid later, but deferred:

- Authenticated web dashboard.
- Web transaction review.
- Web budget setup.
- Web Rex chat.
- Web Rex voice.
- Account connection management.
- Data export.
- Billing/subscription management.
- Admin support tools.
- Public changelog.
- Public docs/help center.

Future web app work should become its own project plan after Plaid landing v1 is live.

## Decision Rules

When deciding whether a feature belongs in v1, ask:

1. Does this help Plaid or a user understand Clarity's purpose, privacy, security, or support path?
2. Can this launch without collecting sensitive financial information on the public site?
3. Can this be implemented quickly without risking the mobile app?
4. Does this avoid implying Plaid endorsement or production approval?

If the answer is not clearly yes, move it to the future backlog.

## Implementation Guardrails

- Public pages should be static or mostly static where possible.
- Any form must collect minimal information.
- No personal financial data should be shown in public screenshots.
- All legal/trust pages must remain reachable without sign-in.
- Public navigation must stay compact and reviewer-friendly.

## File 01 Completion Gate

Before moving beyond landing structure planning:

- Route map exists.
- Home section order exists.
- Header contract exists.
- Footer contract exists.
- Page template contract exists.
- Plaid consent placement contract exists.
- Public FAQ contract exists.
- Launch scope lock exists.

All eight contracts are now created for File 01.
