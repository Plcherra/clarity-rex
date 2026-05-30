# Clarity Hero CTA Contract

Status: File 02 Phase 2 primary CTA approved for initial landing launch.

Purpose: define the hero calls to action so the first viewport invites interest without implying instant Plaid production access, bank connection, or financial advice.

## Primary CTA

Preferred label:

- `Request access`

Acceptable alternative:

- `Join the beta`

Target:

- `/#request-access` or the equivalent request-access form anchor on the home page.

Required meaning:

- The user is asking to join or learn more.
- The user is not connecting a bank account from the public landing page.
- The user is not receiving instant production access.

## Secondary CTA

Preferred label:

- `See how data is handled`

Acceptable alternatives:

- `Read privacy`
- `Review security`

Preferred target:

- `/#data-consent` for a home-page explanation if implemented.

Acceptable targets:

- `/privacy`
- `/security`

Required meaning:

- The secondary CTA helps users and Plaid reviewers inspect trust and data handling before joining.
- The secondary CTA should not compete visually with the primary CTA.

## CTA Pairing

Recommended first viewport CTA pair:

1. Primary: `Request access`
2. Secondary: `See how data is handled`

Use this exact pairing unless a later copy review changes it.

## Forbidden CTA Labels

Do not use these CTA labels in v1:

- `Connect bank`
- `Connect with Plaid`
- `Start Plaid`
- `Launch app`
- `Open dashboard`
- `Get financial advice`
- `Fix my finances`
- `Start saving now`
- `Try Rex`
- `Sign up for Rex`

## Mobile Requirements

- Primary CTA must remain visible in the first viewport on common phone sizes where practical.
- Primary and secondary CTAs may stack vertically on small screens.
- Buttons must have at least 44 logical pixels of tap height where practical.
- CTA text must not wrap awkwardly or shrink below comfortable readability.
- The next trust section should still peek below the hero on mobile.

## Desktop Requirements

- Primary CTA should visually lead.
- Secondary CTA can be a text link or lower-emphasis button.
- CTAs should sit near the headline and supporting copy.
- Do not place CTAs only inside a screenshot or decorative visual.

## Accessibility Requirements

- CTA labels must describe the action.
- Keyboard focus order should reach primary CTA before secondary CTA.
- Buttons and links must have visible focus states.
- Anchor targets must not be hidden behind sticky header behavior.

## Plaid Review Boundaries

The primary CTA must not:

- Launch Plaid Link.
- Ask for bank credentials.
- Ask for account numbers, routing numbers, SSNs, or card numbers.
- Imply Plaid has approved the app.
- Imply the user can connect production accounts immediately from the public page.

## Acceptance Checklist

- Primary CTA is `Request access` or `Join the beta`.
- Secondary CTA points to data handling, privacy, or security details.
- CTA labels work on mobile and desktop.
- CTA copy does not imply instant Plaid production access.
- CTA copy does not make Rex the product.
