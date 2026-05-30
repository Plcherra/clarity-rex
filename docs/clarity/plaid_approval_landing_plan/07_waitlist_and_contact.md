# File 07 - Waitlist & Contact

Goal: provide a lightweight way for users and reviewers to contact Clarity without turning the landing site into a full web app.

## Phase 1 - Contact Requirements

Goal: define required public contact paths.

Files to modify/create:
- `/contact` page
- Footer contact link

Acceptance Criteria:
- Contact page includes support email.
- Includes reason categories: beta access, support, privacy, data deletion, security.
- Avoids collecting sensitive financial details.

Risks & Mitigations:
- Risk: users submit private financial data.
- Mitigation: warn not to include account numbers or sensitive info.

Effort: Small.

## Phase 2 - Waitlist Form Scope

Goal: decide minimum waitlist fields.

Files to modify/create:
- Waitlist form component

Acceptance Criteria:
- Fields are name, email, optional note.
- Consent checkbox explains follow-up communications.
- No bank credentials or financial data are requested.

Risks & Mitigations:
- Risk: collecting too much data.
- Mitigation: keep fields minimal.

Effort: Small.

## Phase 3 - Form Destination

Goal: choose where submissions go.

Files to modify/create:
- Form handler plan

Acceptance Criteria:
- Submission destination is defined: Supabase table, email service, or form provider.
- Spam protection is included.
- Error and success states are defined.

Risks & Mitigations:
- Risk: form breaks silently.
- Mitigation: include test submission and logging.

Effort: Medium.

## Phase 4 - Data Deletion Request Page

Goal: create a clear path for deletion requests.

Files to modify/create:
- `/data-deletion` page

Acceptance Criteria:
- Explains users can request account/data deletion.
- Provides email or form path.
- Explains identity verification may be required.

Risks & Mitigations:
- Risk: deletion promise exceeds tooling.
- Mitigation: describe current manual process accurately.

Effort: Medium.

## Phase 5 - Privacy Request Workflow

Goal: define internal handling for privacy requests.

Files to modify/create:
- Privacy request runbook

Acceptance Criteria:
- Captures request intake, verification, action, confirmation.
- Defines owner/responsible person.
- Avoids ad hoc inbox handling.

Risks & Mitigations:
- Risk: requests get missed.
- Mitigation: document tracking method.

Effort: Small.

## Phase 6 - Security Contact Workflow

Goal: define how security reports are handled.

Files to modify/create:
- Security contact section/runbook

Acceptance Criteria:
- Security reports have a clear email or form.
- Page asks reporters not to include secrets publicly.
- Internal escalation path exists.

Risks & Mitigations:
- Risk: security report ignored.
- Mitigation: route to monitored inbox.

Effort: Small.

## Phase 7 - Confirmation Copy

Goal: make form feedback professional.

Files to modify/create:
- Form success/error copy

Acceptance Criteria:
- Success copy sets expectation without promising instant response.
- Error copy is helpful.
- Copy does not expose backend details.

Risks & Mitigations:
- Risk: vague confirmations reduce trust.
- Mitigation: include next-step language.

Effort: Small.

## Phase 8 - Contact Review Gate

Goal: verify all public contact paths work before deployment.

Files to modify/create:
- Contact QA checklist

Acceptance Criteria:
- Test submissions work.
- Spam protection works.
- Footer and policy links point to contact/deletion pages.

Risks & Mitigations:
- Risk: public forms fail after deploy.
- Mitigation: include deployment smoke test.

Effort: Small.
