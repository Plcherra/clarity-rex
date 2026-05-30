# File 10 - Final Review & Deployment

Goal: prepare the public site and Plaid review package for launch and submission.

## Post-Phase-10 Manual Reminder

After File 10 is complete, do not treat the landing site as Plaid-ready until these manual steps are finished:

- Deploy the static site to the production domain, currently `https://goclarity.app`.
- Open the live site on mobile and desktop.
- Submit one safe waitlist test and one safe contact test through the live forms.
- Check `clarity.rex@gmail.com` inbox and spam.
- Confirm any FormSubmit activation email if prompted, then submit again.
- Verify the success redirect lands on `https://goclarity.app/form-success`.
- Confirm live Privacy, Terms, Security, Data Deletion, and Contact URLs are reachable.
- Use the live URLs in the Plaid questionnaire/submission package.

## Phase 1 - Content Freeze

Goal: freeze landing and policy content for final review.

Status: Complete. Final content freeze is recorded in `final_content_freeze_checklist.md`; public page copy is complete for deployment QA, with legal review status intentionally handled in Phase 2.

Files to modify/create:
- Final content checklist

Acceptance Criteria:
- Home, Privacy, Terms, Security, Data Deletion, and Contact content are complete.
- No placeholders remain.
- Final owner review is recorded.

Risks & Mitigations:
- Risk: last-minute copy churn.
- Mitigation: freeze content before deployment QA.

Effort: Small.

## Phase 2 - Legal Review Marker

Goal: explicitly identify legal review status.

Status: Complete. Legal-review status, attorney-review follow-ups, and the intentional launch decision are recorded in `legal_review_status.md`.

Files to modify/create:
- Legal review notes

Acceptance Criteria:
- Privacy and Terms have review status.
- Any attorney-review TODO is tracked.
- Launch decision is intentional.

Risks & Mitigations:
- Risk: publishing unreviewed legal text unknowingly.
- Mitigation: require explicit sign-off.

Effort: Small.

## Phase 3 - Plaid Questionnaire Prep

Goal: prepare answers for Plaid risk/security diligence.

Status: Complete. Plaid questionnaire draft answers, source URLs, product/data summary, security posture, retention/deletion language, vendor notes, and open verification items are captured in `plaid_questionnaire_prep.md`.

Files to modify/create:
- Plaid questionnaire notes

Acceptance Criteria:
- Answers cover product purpose, data requested, retention, deletion, security, vendors, and support.
- Answers reference public pages.
- No contradictions with public site.

Risks & Mitigations:
- Risk: questionnaire answers drift from site.
- Mitigation: use public pages as source of truth.

Effort: Medium.

## Phase 4 - Domain And HTTPS Check

Goal: ensure domain readiness.

Status: Complete with deployment blocker. The canonical app configuration is correct for `https://goclarity.app`, and public DNS currently resolves to GoDaddy parking rather than the Clarity Cloudflare Pages deployment; required Cloudflare Pages domain actions are documented in `deployment_domain_checklist.md`.

Files to modify/create:
- Deployment/domain checklist

Acceptance Criteria:
- Public domain resolves.
- HTTPS works.
- Canonical URL is configured.

Risks & Mitigations:
- Risk: DNS delay.
- Mitigation: configure domain before final review when possible.

Effort: Small.

## Phase 5 - Production Deploy

Goal: deploy the public site.

Status: Pre-deployment package complete, production deploy blocked. Local build and deployment instructions are captured in `production_deployment_notes.md`; Cloudflare Pages deployment still requires committing/pushing the latest changes and configuring/authenticating Cloudflare.

Files to modify/create:
- Deployment logs/notes

Acceptance Criteria:
- Production build deploys successfully.
- All public routes return 200.
- Form endpoint works in production.

Risks & Mitigations:
- Risk: production env missing.
- Mitigation: verify env checklist before deploy.

Effort: Medium.

## Phase 6 - Post-Deploy Smoke Test

Goal: verify live site behavior.

Files to modify/create:
- Live smoke test notes

Acceptance Criteria:
- Mobile and desktop home page pass.
- Legal pages pass.
- Contact/waitlist form passes.

Risks & Mitigations:
- Risk: only local site was tested.
- Mitigation: test live URL after deploy.

Effort: Small.

## Phase 7 - Plaid Submission Package

Goal: assemble links and summary for Plaid review.

Files to modify/create:
- Plaid submission package

Acceptance Criteria:
- Includes public URL, privacy URL, terms URL, security URL, contact URL.
- Includes concise product description and data-use summary.
- Includes support contact.

Risks & Mitigations:
- Risk: missing required links slows approval.
- Mitigation: use package checklist.

Effort: Small.

## Phase 8 - Launch Retrospective And Backlog

Goal: capture follow-up after launch.

Files to modify/create:
- Landing backlog

Acceptance Criteria:
- Future web app ideas are captured separately.
- Plaid feedback items are tracked.
- Known legal/security improvements are prioritized.

Risks & Mitigations:
- Risk: post-launch improvements get lost.
- Mitigation: create explicit backlog.

Effort: Small.
