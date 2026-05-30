# Clarity Feature Visual Consistency Contract

Status: File 03 Phase 7 visual consistency contract approved for initial landing launch.

Purpose: keep feature sections, screenshots, cards, and trust visuals consistent, readable, and lightweight across the public landing page.

## Visual Direction

The landing page should feel product-led, calm, and inspectable.

Feature visuals should:

- Support the copy rather than compete with it.
- Use staged or synthetic product proof.
- Keep financial details readable where they matter.
- Use consistent framing across dashboard, budgets, Rex, and privacy sections.
- Feel like one Clarity system, not several unrelated screenshots.

Avoid:

- Oversized decorative cards.
- Tiny unreadable phone screenshots.
- Mixed screenshot crops with inconsistent scale.
- Screenshots used as decoration when separate readable copy is needed.
- Heavy shadows, bright gradients, or ornamental visuals that reduce trust.

## Approved Feature Section Pattern

Preferred pattern:

1. Short section title.
2. One concise paragraph.
3. Three to four specific bullets or compact proof points.
4. One visual area.
5. Optional link to relevant policy/support page where the section touches data handling.

This pattern may adapt responsively, but the information order should remain predictable.

## Screenshot Treatment

Screenshots should use one of these treatments:

- Single phone mock with staged app screen.
- Browser-like frame for policy/security pages only.
- Cropped product panel when text remains readable.
- Card grid for privacy/security trust concepts.

Do not mix more than two treatments in one page section.

## Aspect Ratio Rules

Recommended ratios:

- Phone screenshot/mock: `9:19.5` or native device aspect.
- Product panel/card crop: `4:3` or `3:2`.
- Trust card icon area: square icon inside flexible card.
- Hero visual: responsive container with max height rather than fixed viewport height.

Rules:

- Keep repeated feature visuals aligned to the same max width.
- Avoid arbitrary crops that cut off important labels.
- If a screenshot must be cropped, crop to a stable product concept, not a random scroll position.

## Mobile Readability Rules

On mobile:

- Text inside screenshots should be readable or not essential.
- Product copy outside the screenshot must explain the key idea.
- Visuals should not push the CTA or next trust section too far down.
- No horizontal scrolling.
- Feature cards should stack cleanly.
- Images should not overlap safe areas or sticky navigation.

Target checks:

- iPhone SE width.
- iPhone 13/14/15 width.
- iPhone 16 Pro-style tall viewport.
- Desktop width around 1280px.

## Asset Weight And Loading

Performance rules:

- Use optimized image formats where the implementation supports them.
- Export mobile and desktop sizes instead of serving huge originals everywhere.
- Lazy load below-fold screenshots.
- Avoid autoplay video in v1 unless explicitly approved later.
- Keep the first viewport focused on text, CTA, and one lightweight product visual.

Screenshot file naming should be descriptive:

- `clarity-dashboard-cash-flow-staged`
- `clarity-budget-progress-staged`
- `clarity-rex-chat-staged`
- `clarity-privacy-controls-illustration`

## Accessibility Rules

Every visual must have meaningful alt text or be marked decorative by implementation.

Good alt text examples:

- `Clarity dashboard showing synthetic monthly income, spending, and cash flow.`
- `Clarity budget screen showing synthetic category budgets for a staged month.`
- `Rex assistant chat with a staged question about budget context.`

Avoid alt text like:

- `screenshot`
- `image`
- `phone mock`
- `cool dashboard`

## Color And UI Consistency

Use a restrained palette aligned with Clarity's current product tone.

Feature visuals should avoid:

- Dominating the page with a single color family.
- Purple/blue SaaS gradients as the main visual identity.
- Excess beige-on-beige where hierarchy disappears.
- Excess red/green without financial meaning.
- Decorative orbs, bokeh, or abstract shapes.

Use color primarily for:

- Financial meaning.
- CTA emphasis.
- Status or progress.
- Small brand accents.

## Screenshot Readiness Checklist

Before a screenshot is approved:

- It uses synthetic, staged, or fully redacted data.
- It has an entry in the future screenshot asset register.
- It matches the selected aspect ratio/treatment.
- It is readable on mobile or supported by external copy.
- It does not show debug states, error states, import toasts, raw labels, or private content.
- It has draft alt text.
- It does not contradict Privacy, Security, Plaid, or Terms copy.

## Acceptance Checklist

- Assets share aspect ratio and visual treatment.
- Mobile layout avoids tiny unreadable screenshots.
- Feature sections feel consistent and premium.
- No oversized decorative cards.
- Below-fold assets can be optimized and lazy loaded.
- Every visual has an accessibility plan.
