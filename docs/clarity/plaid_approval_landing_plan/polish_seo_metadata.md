# SEO Metadata

Status: File 09 Phase 3 SEO metadata approved for the current landing-site draft.

## Scope

This pass adds baseline metadata for search results, canonical URLs, and social previews without adding overclaiming product language or unsupported Plaid claims.

## Implemented Metadata

Every public page now inherits from `BaseLayout.astro`:

- `<title>`
- `<meta name="description">`
- `<link rel="canonical">`
- Open Graph:
  - `og:site_name`
  - `og:locale`
  - `og:type`
  - `og:title`
  - `og:description`
  - `og:url`
  - `og:image`
  - `og:image:width`
  - `og:image:height`
  - `og:image:alt`
- Twitter summary:
  - `twitter:card`
  - `twitter:title`
  - `twitter:description`
  - `twitter:image`
  - `twitter:image:alt`

## Copy Source

Titles and descriptions are sourced from `apps/web/src/content/site.ts`.

This keeps the public product story centralized and reviewable:

- Product is `Clarity`.
- Rex is described as the assistant inside Clarity.
- Clarity is described as a personal AI financial co-pilot.
- Metadata does not claim banking, advisory, Plaid partnership, guaranteed approval, or guaranteed outcomes.

## Open Graph Image

A static synthetic Open Graph image is included at `apps/web/public/og-image.jpg`.

The image is:

- Static.
- Synthetic.
- Free of personal financial data.
- Sized at `1200x630`.
- Compressed as a JPEG to keep the public asset lightweight.
- Stored in `apps/web/public`.

## Verification

The release build should generate all pages with:

- Page-specific title and description.
- Canonical URLs under `https://goclarity.app`.
- Open Graph and Twitter metadata.

## Acceptance Decision

File 09 Phase 3 passes for the current draft. The site is ready for File 09 Phase 4 sitemap and robots.
