# Clarity Plaid Landing Site Route Map

Status: Phase 1 route contract approved for initial landing launch.

Purpose: define the smallest credible public site Clarity needs before Plaid Trial/Production review. This is a public trust and compliance surface, not a full web app.

## Product Naming Contract

- Product: Clarity
- Assistant inside product: Rex
- Public copy rule: do not call the product "Rex"; describe Rex as the AI assistant inside Clarity.

## Initial Public Routes

| Route | Page | Purpose | Primary Audience | Required Footer Link |
| --- | --- | --- | --- | --- |
| `/` | Home | Explain Clarity, show value proposition, trust signals, Plaid/data consent summary, screenshots, FAQ, and beta CTA. | Users and Plaid reviewers | Yes |
| `/privacy` | Privacy Policy | Explain collected data, Plaid-connected data, Rex data, vendors, retention, deletion, and user rights. | Users and Plaid reviewers | Yes |
| `/terms` | Terms of Service | Define acceptable use, AI/financial advice boundaries, user responsibilities, Plaid connection limits, and service terms. | Users and Plaid reviewers | Yes |
| `/security` | Security & Data Handling | Explain data flow, access controls, encryption posture, vendors, deletion, and security contact. | Users and Plaid reviewers | Yes |
| `/data-deletion` | Data Deletion | Explain how users request account/data deletion and disconnect financial accounts. | Users and Plaid reviewers | Yes |
| `/contact` | Contact | Provide support, privacy, deletion, security, and beta access contact paths. | Users, Plaid reviewers, support requests | Yes |

## Waitlist Decision

Initial decision: do **not** create a separate `/waitlist` route for v1.

Reason:

- Embedding the beta/waitlist CTA on `/` is faster.
- It avoids one extra route for launch QA.
- It keeps the public site compact for Plaid review.

Allowed future change:

- Add `/waitlist` only if the form grows beyond a simple embedded request-access form or needs campaign tracking.

## Header Navigation

Initial header links:

- Clarity logo/name -> `/`
- Privacy -> `/privacy`
- Security -> `/security`
- Contact -> `/contact`
- Primary CTA -> home waitlist/request-access section on `/`

Header non-goals:

- No authenticated dashboard link for v1.
- No Plaid Link launch button for v1.
- No full web app navigation for v1.

## Footer Navigation

Footer links must match the route map:

- Home -> `/`
- Privacy -> `/privacy`
- Terms -> `/terms`
- Security -> `/security`
- Data Deletion -> `/data-deletion`
- Contact -> `/contact`

Footer must also include:

- Support email placeholder until final address is confirmed.
- Operator/company identity placeholder until final legal/operator text is confirmed.
- Copyright year.

## Implementation Notes For Later Phases

- The landing app should live outside `apps/mobile/web`; that folder belongs to Flutter mobile web output.
- Recommended future location: `apps/landing` or `apps/web`.
- The site can be static-first and does not need authenticated app state for Plaid approval.
- Public screenshots must use synthetic or redacted data only.
