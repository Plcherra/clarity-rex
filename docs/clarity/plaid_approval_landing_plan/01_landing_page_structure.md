# File 01 - Landing Page Structure

Goal: define the public website structure for Clarity so Plaid reviewers and future users can quickly understand the product, trust posture, and support paths.

## Phase 1 - Site Map Contract

Goal: decide the exact public routes needed for launch.

Status: Complete. The route contract is captured in `landing_site_route_map.md`; v1 includes `/`, `/privacy`, `/terms`, `/security`, `/data-deletion`, and `/contact`, with waitlist/request access embedded on the home page.

Files to modify/create:
- Landing site route map
- `docs/clarity/plaid_approval_landing_plan/01_landing_page_structure.md`

Acceptance Criteria:
- Routes include `/`, `/privacy`, `/terms`, `/security`, `/data-deletion`, and `/contact`.
- Optional `/waitlist` route is included only if not embedded on home.
- Footer route list matches site map.

Risks & Mitigations:
- Risk: too many pages slow launch.
- Mitigation: keep the first version compact and public-facing.

Effort: Small.

## Phase 2 - Home Page Section Order

Goal: define the landing page information hierarchy.

Status: Complete. The `/` page section order is captured in `home_page_section_outline.md`: hero, trust bar, problem, features, Plaid/data consent, screenshots, FAQ, and final CTA.

Files to modify/create:
- Home page component outline

Acceptance Criteria:
- Sections follow: hero, trust bar, problem, features, Plaid/data consent, screenshots, FAQ, CTA.
- Each section has one clear purpose.
- No section reads like investor pitch copy.

Risks & Mitigations:
- Risk: marketing copy hides compliance details.
- Mitigation: include data access and privacy language on the home page.

Effort: Small.

## Phase 3 - Header And Navigation

Goal: create minimal navigation that feels trustworthy and uncluttered.

Status: Complete. Header and mobile navigation behavior is captured in `header_navigation_contract.md`, including Clarity branding, Privacy, Security, Contact, and a Request access CTA.

Files to modify/create:
- Header/nav component

Acceptance Criteria:
- Header includes Clarity logo/name, Privacy, Security, Contact, and primary CTA.
- Navigation works on mobile without overlap.
- Rex is described as the assistant, not the product.

Risks & Mitigations:
- Risk: nav feels too sparse.
- Mitigation: footer carries full compliance links.

Effort: Small.

## Phase 4 - Footer Compliance Links

Goal: make legal and support access obvious from every page.

Status: Complete. Footer compliance requirements are captured in `footer_compliance_contract.md`, including required route links, support/operator placeholders, mobile behavior, and Plaid-friendly direct access rules.

Files to modify/create:
- Footer component

Acceptance Criteria:
- Footer links Privacy, Terms, Security, Data Deletion, Contact.
- Footer includes support email and copyright/operator identity.
- Links are accessible on mobile.

Risks & Mitigations:
- Risk: missing footer links hurt Plaid trust review.
- Mitigation: make footer shared across all public pages.

Effort: Small.

## Phase 5 - Page Template System

Goal: standardize page layouts for legal, support, and content pages.

Status: Complete. The shared public shell, home/legal/trust/support templates, typography rules, accessibility requirements, and Plaid review constraints are captured in `page_template_contract.md`.

Files to modify/create:
- Public page layout component
- Legal page layout component

Acceptance Criteria:
- Legal pages have readable width, last-updated date, table of contents if long.
- Content pages share header/footer.
- Layout avoids card-inside-card clutter.

Risks & Mitigations:
- Risk: legal pages look unfinished.
- Mitigation: use consistent typography and spacing.

Effort: Medium.

## Phase 6 - Plaid Consent Placement

Goal: place bank-connection consent explanation where users see it before joining.

Status: Complete. Consent placement requirements, approved draft copy, FAQ placement rules, forbidden claims, and Plaid review notes are captured in `plaid_consent_placement_contract.md`.

Files to modify/create:
- Home data consent section
- FAQ section

Acceptance Criteria:
- Copy says Clarity uses Plaid to let users connect financial accounts.
- Copy explains transaction and balance data at a high level.
- Copy links Privacy, Security, and Data Deletion.

Risks & Mitigations:
- Risk: copy sounds like Plaid endorses Clarity.
- Mitigation: use neutral integration language only.

Effort: Small.

## Phase 7 - Public FAQ Structure

Goal: answer trust and data questions without overwhelming users.

Status: Complete. Required FAQ questions, answer boundaries, link requirements, tone rules, and implementation notes are captured in `public_faq_contract.md`.

Files to modify/create:
- FAQ component/content file

Acceptance Criteria:
- FAQ covers what Clarity is, what Rex is, what data is accessed, deletion, security, and support.
- FAQ uses plain language.
- No financial, tax, or investment guarantee claims.

Risks & Mitigations:
- Risk: FAQ becomes legal policy duplicate.
- Mitigation: link detailed policies for specifics.

Effort: Small.

## Phase 8 - Launch Scope Lock

Goal: prevent landing work from expanding into full web app work.

Status: Complete. The v1 launch objective, included scope, explicit non-goals, Plaid Link boundary, future web app backlog, and File 01 completion gate are captured in `landing_launch_scope_lock.md`.

Files to modify/create:
- Launch scope notes

Acceptance Criteria:
- Scope explicitly excludes authenticated dashboard, Plaid Link in browser, and web app parity for v1.
- Follow-up backlog captures future web app ideas.
- Team can start implementation without ambiguity.

Risks & Mitigations:
- Risk: building a web app delays Plaid readiness.
- Mitigation: prioritize public trust and compliance pages first.

Effort: Small.
