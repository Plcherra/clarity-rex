# File 09 - Polish, Testing & SEO

Goal: make the public site feel complete, fast, discoverable, and trustworthy on mobile and desktop.

## Phase 1 - Responsive QA

Goal: verify layout across common sizes.

Status: Complete. Mobile and desktop route checks passed, no horizontal overflow was found, footer links remained visible, and the QA result is captured in `polish_responsive_qa.md`.

Files to modify/create:
- Responsive test checklist

Acceptance Criteria:
- Home, Privacy, Terms, Security, Data Deletion, and Contact work on mobile and desktop.
- No text overlaps or clipped buttons.
- Footer links remain visible.

Risks & Mitigations:
- Risk: legal pages ignored on mobile.
- Mitigation: test all routes, not just home.

Effort: Medium.

## Phase 2 - Accessibility Pass

Goal: make the site usable with assistive technology.

Status: Complete. Skip link, main landmark, form label/description wiring, visible content links, and focus-state improvements are implemented; the accessibility pass is captured in `polish_accessibility_pass.md`.

Files to modify/create:
- Accessibility fixes

Acceptance Criteria:
- Semantic headings are ordered.
- Buttons and form fields have labels.
- Contrast is acceptable.

Risks & Mitigations:
- Risk: visual polish breaks accessibility.
- Mitigation: test keyboard navigation and labels.

Effort: Medium.

## Phase 3 - SEO Metadata

Goal: configure baseline discovery and link previews.

Status: Complete. Canonical URLs, Open Graph tags, Twitter summary tags, and centralized metadata source rules are implemented; the SEO metadata pass is captured in `polish_seo_metadata.md`.

Files to modify/create:
- Metadata config
- Open Graph/Twitter tags

Acceptance Criteria:
- Each page has title and description.
- Home has Open Graph image if available.
- Product description is concise and accurate.

Risks & Mitigations:
- Risk: metadata overclaims capabilities.
- Mitigation: reuse approved value proposition.

Effort: Small.

## Phase 4 - Sitemap And Robots

Goal: make public routes indexable.

Status: Complete. Astro-generated `robots.txt` and `sitemap.xml` expose only the public landing/compliance routes under `https://rexpilot.com`; the QA result is captured in `polish_sitemap_robots.md`.

Files to modify/create:
- `sitemap.xml`
- `robots.txt`

Acceptance Criteria:
- Public pages are listed.
- No private or future app routes are exposed.
- Domain matches deployment.

Risks & Mitigations:
- Risk: staging URLs leak.
- Mitigation: generate per environment carefully.

Effort: Small.

## Phase 5 - Performance Pass

Goal: keep the landing site fast.

Status: Complete. The current site ships no client JavaScript, the social preview image is compressed, no below-fold screenshots are present yet, and future screenshot loading rules are captured in `polish_performance_pass.md`.

Files to modify/create:
- Image optimization
- Lazy loading

Acceptance Criteria:
- Images are compressed.
- Below-fold screenshots lazy load.
- Page avoids unnecessary client-side JavaScript.

Risks & Mitigations:
- Risk: screenshots slow first load.
- Mitigation: use optimized responsive images.

Effort: Medium.

## Phase 6 - Link And Form QA

Goal: catch broken links before launch.

Files to modify/create:
- Link test checklist

Acceptance Criteria:
- All nav/footer links work.
- Legal cross-links work.
- Forms submit and fail gracefully.

Risks & Mitigations:
- Risk: broken compliance links harm trust.
- Mitigation: run link checks before deploy.

Effort: Small.

## Phase 7 - Copy Consistency Pass

Goal: remove inconsistent product or data language.

Files to modify/create:
- Copy review notes

Acceptance Criteria:
- Product is always Clarity.
- Rex is always the assistant.
- Plaid is referenced accurately.

Risks & Mitigations:
- Risk: old app/internal names leak.
- Mitigation: search for banned/internal terms.

Effort: Small.

## Phase 8 - Polish Review Gate

Goal: approve site polish before final deployment review.

Files to modify/create:
- Polish QA checklist

Acceptance Criteria:
- No placeholder copy.
- No broken assets.
- Accessibility, metadata, performance, and links are checked.

Risks & Mitigations:
- Risk: rushing final pass.
- Mitigation: use checklist before deploy.

Effort: Small.
