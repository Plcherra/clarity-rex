# File 10 - Final Review & Deployment

Goal: prepare the public site and Plaid review package for launch and submission.

## Phase 1 - Content Freeze

Goal: freeze landing and policy content for final review.

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
