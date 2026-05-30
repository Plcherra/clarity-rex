# File 08 - Technical Implementation

Goal: implement the landing site quickly with a maintainable stack, clean routing, low operational risk, and easy deployment.

## Phase 1 - Stack Decision

Goal: choose the fastest reliable implementation path.

Status: Complete. Static-first Astro implementation in an isolated `apps/web` folder is selected in `technical_stack_decision.md`; full web app scope is explicitly deferred.

Files to modify/create:
- Technical decision note

Acceptance Criteria:
- Stack is selected: static site, Next.js, Astro, or equivalent.
- Decision considers speed, SEO, deployment, and future expansion.
- Full web app scope is explicitly deferred.

Risks & Mitigations:
- Risk: choosing heavy stack delays launch.
- Mitigation: prefer static-first implementation.

Effort: Small.

## Phase 2 - App Folder Structure

Goal: decide where the landing code lives.

Status: Complete. The isolated Astro app scaffold lives in `apps/web`, and the route/folder contract is captured in `technical_app_structure.md`.

Files to modify/create:
- `apps/web` or equivalent
- Routing folders

Acceptance Criteria:
- Folder does not interfere with mobile or backend builds.
- Scripts are clear.
- README explains local dev and deploy.

Risks & Mitigations:
- Risk: monorepo confusion.
- Mitigation: isolate web dependencies.

Effort: Medium.

## Phase 3 - Shared Content Model

Goal: keep page copy easy to review.

Status: Complete. Shared route metadata, product naming, footer/header links, CTA, trust notes, and FAQ copy live in `apps/web/src/content/site.ts`; the content model contract is captured in `technical_content_model.md`.

Files to modify/create:
- Content files or constants

Acceptance Criteria:
- Landing copy, FAQ, policy metadata, and footer links are centralized where useful.
- Legal text remains readable and editable.
- No copy hardcoded across many components unnecessarily.

Risks & Mitigations:
- Risk: over-abstracting content.
- Mitigation: extract only repeated content.

Effort: Medium.

## Phase 4 - Styling System

Goal: create a clean minimalist visual system.

Status: Complete. The initial global style system lives in `apps/web/src/styles/global.css`, is applied through `BaseLayout.astro`, and is documented in `technical_styling_system.md`.

Files to modify/create:
- Theme/styles
- Core layout components

Acceptance Criteria:
- Uses restrained palette, readable typography, consistent spacing.
- Avoids one-note beige/dark/purple-heavy design.
- Buttons, links, cards, and forms are consistent.

Risks & Mitigations:
- Risk: landing looks generic.
- Mitigation: use product screenshots and strong copy as visual anchors.

Effort: Medium.

## Phase 5 - Form Backend

Goal: implement waitlist/contact reliably.

Status: Complete. Waitlist/contact forms use a static hosted-form-provider-compatible implementation routed to `clarity.rex@gmail.com`, with validation, honeypot spam protection, success/error routes, and implementation notes in `technical_form_backend.md`.

Files to modify/create:
- Form API route or provider config
- Database table if needed

Acceptance Criteria:
- Form validates fields.
- Spam protection exists.
- Success/error states work.

Risks & Mitigations:
- Risk: exposing secrets client-side.
- Mitigation: server-side form handling only for secrets.

Effort: Medium.

## Phase 6 - Environment Management

Goal: define safe environment config.

Status: Complete. `apps/web/.env.example` defines the public `PUBLIC_SITE_URL`, Astro defaults to `https://goclarity.app`, local setup is documented in `apps/web/README.md`, and the environment contract is captured in `technical_environment_config.md`.

Files to modify/create:
- `.env.example`
- Deployment env docs

Acceptance Criteria:
- Public and secret env vars are separated.
- No secrets committed.
- Local setup is documented.

Risks & Mitigations:
- Risk: leaking API keys.
- Mitigation: review env files before commit.

Effort: Small.

## Phase 7 - Deployment Pipeline

Goal: make deployment repeatable.

Status: Complete. Cloudflare Pages is selected for `goclarity.app`, the build/domain/rollback workflow is documented in `technical_deployment_pipeline.md`, and `scripts/web_release_build.sh` provides a repeatable local release build.

Files to modify/create:
- Deploy docs/scripts

Acceptance Criteria:
- Deployment target is chosen.
- Build command, env vars, and domain setup are documented.
- Rollback path is documented.

Risks & Mitigations:
- Risk: one-off manual deploy.
- Mitigation: script or document exact steps.

Effort: Medium.

## Phase 8 - Technical Review Gate

Goal: verify implementation foundation before polish.

Status: Complete. The technical foundation passed release build and local route smoke checks, form wiring was verified, and the review decision is captured in `technical_review_gate.md`.

Files to modify/create:
- Technical QA notes

Acceptance Criteria:
- Local build passes.
- Production build passes.
- Routes render and forms submit in test environment.

Risks & Mitigations:
- Risk: deploy differs from local.
- Mitigation: test preview deploy before final.

Effort: Small.
