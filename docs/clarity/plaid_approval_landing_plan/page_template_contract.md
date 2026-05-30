# Clarity Landing Page Template Contract

Status: Phase 5 page template system approved for initial landing launch.

Purpose: keep every public Clarity page consistent, readable, and Plaid-review friendly without turning the landing site into a full web app.

## Shared Public Page Shell

Every public page must use the same outer shell:

1. Top header from `header_navigation_contract.md`.
2. Main content area with one clear page purpose.
3. Footer from `footer_compliance_contract.md`.

Required shell behavior:

- Header and footer appear on every public route.
- The page title is visible without requiring scrolling on normal mobile screens where practical.
- Body content is constrained to a readable width.
- No page launches Plaid Link or asks for bank credentials in v1.
- No authenticated dashboard controls appear in the public site.

## Template Types

### Home Template

Route:

- `/`

Use for:

- Product positioning.
- Trust explanation.
- Request access CTA.
- Plaid/data consent overview.
- FAQ preview.

Layout rules:

- Full-width sections are allowed.
- Hero copy must make Clarity the product and Rex the assistant.
- Compliance and consent copy must be visible before the final CTA.
- Avoid dense legal text on the home page; link to detailed pages instead.

### Legal Template

Routes:

- `/privacy`
- `/terms`

Use for:

- Privacy Policy.
- Terms of Service.

Layout rules:

- Use a readable content width, ideally around 720-860 px on desktop.
- Include a visible page title.
- Include a visible `Last updated` date near the top.
- Include a short intro paragraph explaining the document purpose.
- Include a table of contents when the page has more than six major sections.
- Use clear section headings and short paragraphs.
- Avoid decorative cards around policy text.

Required legal metadata:

- Product name: Clarity.
- Rex described only as the assistant inside Clarity.
- Operator/company identity placeholder until final legal identity is confirmed.
- Support/contact path.
- Attorney review note must be resolved before production launch.

### Trust Content Template

Routes:

- `/security`
- `/data-deletion`

Use for:

- Security posture.
- Data handling overview.
- Data deletion and account disconnection instructions.

Layout rules:

- Start with a plain-language summary.
- Use short grouped sections for what data is used, why, how it is protected, and how users control it.
- Include a clear user action path.
- Link to Privacy and Contact.
- Avoid vague security claims that cannot be supported.

### Support Template

Route:

- `/contact`

Use for:

- Support contact.
- Waitlist/request access intake if not embedded elsewhere.
- Privacy/security request routing.

Layout rules:

- State expected response path or support email.
- Ask users not to send bank passwords, account numbers, or sensitive financial details.
- Collect minimal information only.
- Include spam-protection requirements if a form is implemented.
- Link Data Deletion for deletion requests.

## Typography And Spacing Contract

All templates must follow these rules:

- One H1 per page.
- Headings should describe the user-facing topic, not internal implementation.
- Body copy should use plain language and avoid financial jargon.
- Paragraphs should stay short enough to scan on mobile.
- Buttons must use action-oriented text, such as `Request access`, `Contact support`, or `Read privacy policy`.
- Avoid long uppercase text except for small labels where the design already supports it.

## Layout Constraints

Required constraints:

- No card-inside-card layouts.
- No dense multi-column legal text.
- No horizontal scrolling on mobile.
- No important footer links hidden behind accordions.
- No first-viewport modal or cookie banner that blocks Plaid review.
- Mobile layout must be checked on small and large iPhone widths before launch.

## Accessibility Contract

All templates must support:

- Semantic `header`, `main`, and `footer` landmarks where the stack supports them.
- Keyboard reachable links and buttons.
- Descriptive link text.
- Color contrast that remains readable on white and off-white backgrounds.
- Form labels that remain visible when fields are focused.

## Plaid Review Contract

The template system must make these pages easy to inspect:

- `/privacy`
- `/terms`
- `/security`
- `/data-deletion`
- `/contact`

Plaid-friendly requirements:

- Legal and trust pages must be reachable from both header or footer paths.
- Data deletion must be its own route.
- Privacy and Security language must not conflict.
- The public site must not imply Plaid endorsement.
- The site must not claim Clarity is a bank, broker, lender, tax advisor, or investment advisor.

## Open Placeholders To Resolve Before Deployment

- Final legal/company/operator identity.
- Final support email.
- Final `Last updated` dates.
- Whether Contact uses a form, mailto link, or both.
- Whether request access is embedded on Home only or mirrored on Contact.
