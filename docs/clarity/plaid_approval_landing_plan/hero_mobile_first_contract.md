# Clarity Mobile-First Hero Contract

Status: File 02 Phase 7 mobile-first hero approved for initial landing launch.

Purpose: make the landing hero work beautifully on phones first, where Plaid reviewers and early users may inspect the site quickly.

## Mobile Hero Priority Order

On mobile, the hero should prioritize:

1. Clarity brand/name.
2. Headline.
3. Supporting copy.
4. Primary CTA.
5. Secondary CTA or data-handling link.
6. Short trust subcopy.
7. Compact product visual or next-section peek.

If space is tight, reduce visual height before reducing message clarity.

## First Viewport Requirement

The first mobile viewport should show:

- Clarity identity.
- The main headline.
- Enough supporting copy to understand the product.
- The primary CTA.
- A visible hint of either the trust section or product visual.

The hero should not require scrolling before the user knows what Clarity is.

## Safe Area Requirements

Hero layout must account for:

- iPhone dynamic island.
- iPhone notch.
- Browser address bars.
- Mobile header height.
- Sticky header behavior if used.

Text, CTA buttons, and important visual content must not overlap safe areas.

## Target Device Checks

Before launch, check the hero on:

- iPhone SE width.
- iPhone 13/14/15 standard width.
- iPhone 15/16 Pro-style dynamic island dimensions.
- A large desktop viewport.

The plan can be implemented without exact device names, but these size classes must be represented in QA.

## Copy Length Constraints

Mobile hero copy should stay compact:

- Headline: ideally one to three short lines.
- Supporting copy: one short paragraph.
- Trust subcopy: one short line or up to three compact bullets.
- CTA labels: no awkward wrapping.

If copy becomes too tall, move detail into:

- Trust bar.
- Plaid/data consent section.
- FAQ.
- Privacy/Security pages.

## Visual Constraints

The hero visual on mobile should be:

- Compact.
- Product-led.
- Optional above the fold if space is tight.
- Never more important than the headline and CTA.

Rules:

- Do not place a huge phone mock before the headline.
- Do not let screenshots force users to scroll past the CTA.
- Do not show unreadable tiny UI as the only explanation of the product.

## CTA Behavior

Mobile CTA rules:

- Primary CTA appears before secondary CTA.
- Primary and secondary CTA may stack.
- Minimum tap target should be 44 logical pixels where practical.
- CTA row/stack must not overlap the hero visual.
- Anchor target must land cleanly below sticky header if one exists.

## Accessibility Requirements

- Hero content should follow logical reading order in the DOM.
- Button and link focus states must be visible.
- Alt text for the hero visual must explain the product screenshot or mock.
- No essential information should exist only inside image text.

## Acceptance Checklist

- Headline, CTA, and trust subcopy fit above the fold on common phones where practical.
- The next section or hero visual peeks below the fold.
- Text does not overlap dynamic island, notch, or sticky header.
- Mobile hero still feels premium and not cramped.
- Product clarity is preserved before visual decoration.
