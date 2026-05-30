# Clarity Landing Shared Content Model

Status: File 08 Phase 3 shared content model approved for initial landing launch draft.

Purpose: keep public landing copy, route metadata, footer links, FAQ entries, and repeated trust copy easy to review without scattering duplicated text across components.

## Decision

Use a small TypeScript content module:

- `apps/web/src/content/site.ts`

The module centralizes repeated public content while leaving legal and policy body copy readable inside dedicated page/content files.

## Centralized Now

Centralize:

- Product naming.
- Assistant naming.
- Public route metadata.
- Header links.
- Footer links.
- Primary CTA.
- Repeated trust notes.
- Launch FAQ entries.
- Public support/operator placeholders.

## Keep Readable In Page Files

Do not over-extract:

- Long Privacy Policy body sections.
- Long Terms of Service body sections.
- Long Security/Data Handling body sections.
- Detailed Data Deletion explanations.

Those should remain easy to review as prose when implemented.

## Product Naming Contract

The content model enforces:

- Product name: `Clarity`
- Assistant name: `Rex`

Public copy should describe Rex as the assistant inside Clarity, not as the product name.

## Route Metadata Contract

Each public route has:

- `path`
- `label`
- `title`
- `description`
- `footerRequired`

This supports page titles, metadata, header/footer navigation, sitemap generation, and link checks in later phases.

## Footer Link Contract

Footer links come from required public routes.

This avoids mismatches between:

- The route map.
- Footer compliance requirements.
- Page implementation.
- SEO/link testing.

## Legal And Compliance Review Position

The content model should help reviewers find repeated public claims quickly.

It must not hide legal obligations inside clever abstractions. If a page needs a detailed legal sentence, keep it visible in that page or a clearly named legal content file.

## Anti-Overengineering Rule

Extract only content that is:

- Repeated across pages.
- Used by navigation or metadata.
- Used by tests or route generation.
- Likely to change globally.

Do not build a CMS, localization layer, or complex schema for v1.

## Acceptance Checklist

- Landing copy, FAQ, metadata, and footer links have a shared source where useful.
- Legal text can remain readable and editable.
- No repeated route/footer copy needs to be hardcoded in multiple components.
- Product naming rules are represented in the content model.
- The model supports later SEO and link validation.
