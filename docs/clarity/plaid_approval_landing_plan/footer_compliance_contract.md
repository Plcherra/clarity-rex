# Clarity Landing Footer Compliance Contract

Status: Phase 4 footer compliance contract approved for initial landing launch.

Purpose: make legal, privacy, security, and support access obvious from every public page so users and Plaid reviewers can quickly verify Clarity's trust posture.

## Footer Link Contract

Footer links must appear on every public page:

| Label | Route | Required |
| --- | --- | --- |
| Home | `/` | Yes |
| Privacy | `/privacy` | Yes |
| Terms | `/terms` | Yes |
| Security | `/security` | Yes |
| Data Deletion | `/data-deletion` | Yes |
| Contact | `/contact` | Yes |

Footer links must match `landing_site_route_map.md`.

## Footer Content Blocks

### Brand Block

Required content:

- Clarity name or logo.
- Short description: "A personal AI financial co-pilot with Rex inside."
- One sentence trust note: "Built around user-authorized account connections and clear data controls."

Copy constraints:

- Do not call Rex the product.
- Do not imply Clarity is a bank, broker, tax advisor, or Plaid-endorsed product.

### Compliance Links Block

Required content:

- Privacy
- Terms
- Security
- Data Deletion
- Contact

Optional content:

- Home link if useful on long pages.

### Support Block

Required content:

- Support email placeholder until final address is confirmed.
- Security/privacy contact path, either email or Contact page.
- Short instruction: users should not send bank credentials, account numbers, or sensitive financial details through public contact forms.

### Operator Block

Required content:

- Operator/company identity placeholder until final legal text is confirmed.
- Copyright year.
- "All rights reserved" if desired.

## Mobile Footer Requirements

- Footer stacks into readable groups.
- Links remain at least 44 logical pixels tall where practical.
- Text does not require horizontal scrolling.
- Support email wraps cleanly.

## Accessibility Requirements

- Footer is wrapped in a semantic `footer` landmark where the web stack supports it.
- Link text must be descriptive.
- Keyboard focus order follows visual order.
- Color contrast must remain readable in footer background.

## Plaid-Friendly Requirements

- Privacy, Terms, Security, Data Deletion, and Contact must be reachable without opening a menu.
- Footer must not hide legal links behind vague labels like "Resources."
- Data Deletion must be a direct link, not only mentioned inside Privacy.

## Footer Non-Goals For V1

- No social media links unless real and maintained.
- No investor or press links.
- No pricing link unless pricing is finalized.
- No authenticated dashboard link.
- No Plaid Link launch action.

## Open Placeholders To Resolve Before Deployment

- Final support email.
- Final operator/legal identity.
- Final copyright holder text.
- Whether Contact form or email is the primary privacy request intake path.
