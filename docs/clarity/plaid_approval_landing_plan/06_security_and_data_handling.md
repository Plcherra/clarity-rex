# File 06 - Security & Data Handling

Goal: create a trust-building Security and Data Handling page that explains Clarity's practical safeguards without overpromising.

## Phase 1 - Security Page Scope

Goal: define what the public Security page should cover.

Status: Complete. Security page identity, audience, approved scope, draft opening copy, required sections, forbidden claims, and launch review questions are captured in `security_page_scope.md`.

Files to modify/create:
- `/security` page content

Acceptance Criteria:
- Covers data flow, access controls, encryption posture, vendors, deletion, and support.
- Uses user-friendly language.
- Avoids claiming certifications not held.

Risks & Mitigations:
- Risk: security page overclaims.
- Mitigation: describe current practices and planned improvements separately.

Effort: Small.

## Phase 2 - Data Flow Explanation

Goal: explain how data moves through Clarity.

Status: Complete. Public data-flow copy, high-level diagram, flow steps, Rex context boundary, forbidden internals, and review checklist are captured in `security_data_flow.md`.

Files to modify/create:
- Data flow section

Acceptance Criteria:
- Explains user consent, Plaid connection, backend storage, app display, and Rex context.
- Uses a simple diagram or bullets.
- Does not expose secrets or architecture internals.

Risks & Mitigations:
- Risk: too technical for users.
- Mitigation: keep details high-level.

Effort: Medium.

## Phase 3 - Access Control Story

Goal: explain who can access user data.

Status: Complete. User authentication, user-scoped access, internal access principles, support access boundaries, account-security responsibilities, forbidden claims, and verification questions are captured in `security_access_controls.md`.

Files to modify/create:
- Access controls section

Acceptance Criteria:
- Explains user authentication.
- Explains least-privilege/admin access principle.
- Explains support access is limited and purpose-bound.

Risks & Mitigations:
- Risk: claiming controls not implemented.
- Mitigation: verify implementation before publishing.

Effort: Medium.

## Phase 4 - Encryption And Storage

Goal: explain protection of data in transit and at rest.

Status: Complete. HTTPS/TLS, hosted database/storage protections, provider verification, unsupported encryption claims, public copy blocks, and launch review questions are captured in `security_encryption_storage.md`.

Files to modify/create:
- Encryption/storage section

Acceptance Criteria:
- Mentions HTTPS/TLS for data in transit.
- Mentions hosted database/storage protections at rest where accurate.
- Avoids unsupported details.

Risks & Mitigations:
- Risk: exact encryption claims depend on vendors.
- Mitigation: verify vendor docs before final copy.

Effort: Small.

## Phase 5 - AI And Voice Vendor Handling

Goal: explain how Rex, speech, and TTS providers fit into data handling.

Status: Complete. Rex context boundaries, AI model provider processing, speech-to-text, text-to-speech, audio/transcript/generated-response distinctions, retention verification, and public copy blocks are captured in `security_ai_voice_vendor_handling.md`.

Files to modify/create:
- AI/voice data section

Acceptance Criteria:
- Explains AI and voice services may process conversation/audio-derived content to provide Rex.
- Distinguishes audio, transcripts, and generated responses.
- Links Privacy Policy.

Risks & Mitigations:
- Risk: hiding AI processing from users.
- Mitigation: state it plainly.

Effort: Medium.

## Phase 6 - Deletion And Disconnection

Goal: explain account disconnection and deletion paths.

Status: Complete. Disconnection vs deletion boundaries, account/deletion request flow, support/contact requirements, backup/legal constraints, public copy blocks, and verification questions are captured in `security_deletion_disconnection.md`.

Files to modify/create:
- Security page deletion section
- `/data-deletion` page link

Acceptance Criteria:
- Explains users can disconnect financial accounts.
- Explains users can request deletion.
- Provides support contact.

Risks & Mitigations:
- Risk: deletion process not automated yet.
- Mitigation: publish a manual support flow if accurate.

Effort: Small.

## Phase 7 - Incident And Support Language

Goal: establish trust if something goes wrong.

Status: Complete. Security contact copy, report categories, sensitive-data warnings, support expectations, internal escalation requirements, public copy blocks, and launch verification questions are captured in `security_incident_support_language.md`.

Files to modify/create:
- Security contact section

Acceptance Criteria:
- Provides security/support email.
- Explains users can report security concerns.
- Does not promise unrealistic response times unless support can meet them.

Risks & Mitigations:
- Risk: support SLA overpromise.
- Mitigation: keep response language general.

Effort: Small.

## Phase 8 - Security Review Gate

Goal: approve security copy before publishing.

Status: Complete. Security launch blockers, source inputs, implementation verification, Privacy/Terms alignment, Plaid questionnaire reuse, placeholder checks, and final acceptance checklist are captured in `security_review_gate.md`.

Files to modify/create:
- Security review checklist

Acceptance Criteria:
- No unsupported certifications or claims.
- Vendor/data handling matches backend reality.
- Plaid questionnaire answers can reference this page.

Risks & Mitigations:
- Risk: public copy and Plaid answers diverge.
- Mitigation: use this page as source material for questionnaire.

Effort: Small.
