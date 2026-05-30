# Clarity Landing Technical Stack Decision

Status: File 08 Phase 1 stack decision approved for initial landing launch draft.

Purpose: choose the fastest reliable implementation path for the public Clarity landing site, legal/compliance pages, waitlist/contact flow, and Plaid review surface.

## Decision

Use a static-first web app in a new isolated `apps/web` folder.

Recommended stack:

- Astro for static-first pages, SEO, content-heavy routes, and fast launch speed.
- TypeScript for maintainable content/config contracts.
- Plain CSS or scoped Astro styles for the initial launch.
- Minimal client JavaScript only where needed for forms, navigation, and small interactions.

Do not build the full Clarity web app in this launch track.

## Why This Stack Wins For Plaid Approval

The first Plaid review need is not a feature-rich browser app. It is a credible public trust surface that explains:

- What Clarity is.
- Who Rex is.
- What data users authorize through Plaid.
- Why the data is used.
- How privacy, security, deletion, and support work.
- How a user can contact Clarity.

Astro fits this because it is optimized for static content, low JavaScript, good metadata control, and simple deployment.

## Options Considered

### Static HTML/CSS

Pros:

- Fastest possible runtime.
- No framework overhead.
- Easy to host anywhere.

Cons:

- More manual duplication across pages.
- Legal/footer/navigation updates are easier to miss.
- Content reuse and route structure become clumsy as the site grows.

Verdict: acceptable, but less maintainable than Astro.

### Astro

Pros:

- Static-first by default.
- Strong SEO and metadata control.
- Great fit for landing, legal, security, and contact pages.
- Component reuse without shipping unnecessary client JavaScript.
- Easy to expand later into islands for forms or light interactive demos.

Cons:

- Adds one web dependency set to the monorepo.
- Team needs a small amount of Astro convention knowledge.

Verdict: preferred launch stack.

### Next.js

Pros:

- Strong ecosystem.
- Good path if a full authenticated web app becomes near-term.
- API routes can support server-side form handling.

Cons:

- Heavier than needed for this landing/compliance launch.
- Easier to drift into full web-app scope.
- More runtime/deployment decisions than static-first pages require.

Verdict: defer unless the public landing site immediately needs authenticated web app features.

### Full Web App

Pros:

- Could eventually mirror the mobile product.
- Useful after Plaid, billing, account management, and desktop workflows mature.

Cons:

- Too large for the current Plaid approval milestone.
- Increases security, privacy, authentication, and support surface area.
- Delays launch and compliance review.

Verdict: explicitly out of scope for this track.

## Launch Scope

Build now:

- Landing page.
- Feature sections with approved screenshots or placeholder-safe visual slots.
- Privacy Policy.
- Terms of Service.
- Security/Data Handling.
- Data Deletion.
- Contact.
- Waitlist/contact form shell or provider integration.
- Footer, metadata, sitemap, robots, Open Graph, favicon.

Defer:

- Authenticated web dashboard.
- Plaid Link in browser.
- Bank account management in browser.
- Rex chat/voice in browser.
- User billing/subscription portal.
- Admin/support console.

## Deployment Direction

Preferred deployment target:

- Static hosting with preview deploys, such as Vercel, Netlify, Cloudflare Pages, or a static VPS/Nginx path.

Selection should happen in File 08 Phase 7 after folder structure, build command, environment needs, and form destination are known.

## SEO And Performance Position

The stack must support:

- Unique metadata per route.
- Clean canonical URLs.
- Open Graph/Twitter card metadata.
- Sitemap and robots.txt.
- Fast mobile load.
- No heavy animation framework for launch.
- No unnecessary tracking scripts.

## Form Handling Position

Initial forms should remain simple:

- Hosted form provider or server-side endpoint.
- Spam protection.
- No secrets in client code.
- No Plaid tokens or financial credentials collected.
- Confirmation/error copy follows `form_confirmation_copy.md`.

The stack decision does not force the final form provider. That remains part of File 08 Phase 5.

## Future Expansion Path

Astro keeps these later options open:

- Add light client islands for richer product demos.
- Add serverless form endpoints if the deployment provider supports them.
- Move to a richer authenticated web app later under a separate app or route group.
- Keep legal/content pages static even if a future app uses another framework.

## Acceptance Checklist

- Static-first implementation path is selected.
- Speed, SEO, deployment, and future expansion are considered.
- Full web app scope is explicitly deferred.
- Landing site code will live outside mobile/backend modules.
- The decision supports Plaid review needs without overbuilding.
