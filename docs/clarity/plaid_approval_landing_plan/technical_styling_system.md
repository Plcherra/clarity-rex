# Clarity Landing Styling System

Status: File 08 Phase 4 styling system approved for initial landing launch draft.

Purpose: define the first visual system for the public Clarity landing site so the site feels professional, readable, mobile-friendly, and Plaid-review ready.

## Decision

Use one global stylesheet for the initial launch:

- `apps/web/src/styles/global.css`

The stylesheet defines:

- Color tokens.
- Spacing tokens.
- Typography defaults.
- Header and footer layout.
- Buttons.
- Panels.
- Form field shells.
- Responsive behavior.

## Visual Direction

The public site should feel:

- Calm.
- Trustworthy.
- Focused.
- Financially literate.
- Light enough for fast review.

The visual system should not feel like:

- A crypto landing page.
- A heavy enterprise dashboard.
- A generic AI hype page.
- A monochrome beige mockup.
- A dark/purple gradient product page.

## Palette Contract

Use a restrained mixed palette:

- Warm canvas background.
- White surfaces.
- Dark ink text.
- Muted gray-brown supporting text.
- Green for positive trust/data-control emphasis.
- Gold for Clarity/Rex accent.
- Red only for caution/error states.

This avoids a one-note palette while still matching the mobile app's warm, calm product feel.

## Typography Contract

- Use system sans-serif stack for launch.
- Keep letter spacing at `0` except short uppercase eyebrow labels.
- Use large hero type only on the real home hero.
- Use smaller headings inside panels, footer, and policy pages.
- Do not scale font sizes with viewport width only; use bounded `clamp()` values.

## Layout Contract

- Use a max-width page container.
- Keep header sticky but restrained.
- Legal/footer links remain visible and readable.
- Cards/panels use `8px` radius.
- Avoid nested cards.
- Avoid decorative blobs, orbs, and non-product gradient backgrounds.

## Component Classes

Initial classes:

- `.site-header`
- `.site-header__inner`
- `.brand-link`
- `.brand-mark`
- `.site-nav`
- `.button`
- `.button--secondary`
- `.site-main`
- `.hero`
- `.hero__actions`
- `.eyebrow`
- `.section`
- `.section__header`
- `.card-grid`
- `.panel`
- `.placeholder-form`
- `.field-shell`
- `.page-shell`
- `.site-footer`
- `.footer-nav`
- `.footer-meta`

## Form Styling Position

The current waitlist form is intentionally disabled until File 08 Phase 5.

The style system already includes:

- Label.
- Input.
- Textarea.
- Button.
- Disabled shell readiness.

Phase 5 should add real validation and submission behavior without changing the visual language unnecessarily.

## Responsive Requirements

The style system must support:

- 320px width.
- Small iPhones.
- Modern large iPhones.
- Tablets.
- Desktop.

Header links may wrap on mobile. Primary action buttons become full-width on very narrow screens.

## Acceptance Checklist

- Restrained palette exists.
- Typography and spacing defaults exist.
- Header, footer, buttons, panels, and form shells share a consistent visual system.
- Mobile layout avoids horizontal overflow.
- The site avoids one-note beige, dark blue, and purple-gradient dominance.
- The styling remains simple enough to evolve during File 09 polish.
