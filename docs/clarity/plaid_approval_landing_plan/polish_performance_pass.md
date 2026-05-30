# Performance Pass

Status: File 09 Phase 5 performance pass complete.

## Scope

This pass keeps the initial Clarity public site lightweight for launch while leaving clear rules for future screenshot and media additions.

## Current Asset Profile

The implemented public site is static and intentionally small:

- Astro static output.
- No client-side JavaScript bundles.
- One shared CSS asset.
- One public social preview image.
- No below-fold product screenshots yet.
- No third-party analytics or tracking scripts.

## Image Optimization

The social preview image is stored as:

- `apps/web/public/og-image.jpg`

Asset rules:

- Size: `1200x630`.
- Source: synthetic design.
- Sensitive data: none.
- Public use: approved for link previews.
- Compression: JPEG, currently under `100 KB`.

The previous PNG version was replaced because it was materially larger for the same visual purpose.

## Lazy Loading Rule

There are no page-rendered screenshots or below-fold images in the current implementation.

When screenshots are added later:

- Above-fold hero visuals may use eager loading only if they are essential.
- Below-fold screenshots must use `loading="lazy"`.
- Decorative or secondary product images should include explicit `width` and `height`.
- Screenshots must be compressed and reviewed under the screenshot redaction policy.

## JavaScript Rule

The public landing site should remain mostly static.

Do not add client-side JavaScript unless the feature cannot be implemented safely with HTML/CSS/static Astro rendering. Any future JS must have a specific purpose, a rollback path, and no hidden tracking behavior.

## Verification

Required verification:

- Release build completes.
- NPM audit reports no vulnerabilities.
- No generated JavaScript files exist in `dist`.
- Largest public assets are reviewed.
- Social image metadata points to the compressed image.

## Acceptance Decision

File 09 Phase 5 passes. The site is ready for File 09 Phase 6 link and form QA.
