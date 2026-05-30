# Clarity Security Review Gate

Status: File 06 Phase 8 security review gate approved for initial landing launch draft.

## Purpose

This gate defines what must be true before Clarity's Security and Data Handling page is published on the public landing site or reused as supporting evidence for Plaid risk/security diligence.

The Security page is product-specific launch copy. It must describe verified practices, avoid unsupported guarantees, and align with the live product, Privacy Policy, Terms of Service, Data Deletion page, Contact page, FAQ, and Plaid questionnaire answers.

## Required Security Draft Inputs

The Security and Data Handling page must be assembled from these approved planning contracts:

- `security_page_scope.md`
- `security_data_flow.md`
- `security_access_controls.md`
- `security_encryption_storage.md`
- `security_ai_voice_vendor_handling.md`
- `security_deletion_disconnection.md`
- `security_incident_support_language.md`

Supporting alignment files:

- `privacy_policy_scope.md`
- `privacy_data_categories.md`
- `privacy_plaid_data_use.md`
- `privacy_purpose_of_processing.md`
- `privacy_sharing_and_vendors.md`
- `privacy_retention_and_deletion.md`
- `privacy_user_rights_and_choices.md`
- `privacy_review_gate.md`
- `terms_scope.md`
- `terms_eligibility_accounts.md`
- `terms_ai_assistant_disclaimer.md`
- `terms_plaid_connection.md`
- `terms_financial_advice_boundary.md`
- `terms_acceptable_use.md`
- `terms_availability_limitation_changes.md`
- `terms_review_gate.md`
- `privacy_feature_section.md`
- `public_faq_contract.md`
- `footer_compliance_contract.md`
- `landing_site_route_map.md`

## Launch Blockers

Do not publish the Security page if any of these are true:

- The page still contains placeholders such as `[support/contact email]`, `[security contact email]`, `[operator/legal entity]`, `[last updated date]`, or unresolved TODO markers.
- The page claims a security control, vendor behavior, deletion flow, support workflow, certification, audit, encryption detail, retention setting, or access control that has not been verified.
- The page conflicts with Privacy, Terms, Data Deletion, Contact, FAQ, landing page, mobile app behavior, or backend behavior.
- The page implies Plaid endorses, sponsors, certifies, audits, or approves Clarity.
- The page implies Clarity is a bank, broker, lender, financial advisor, tax advisor, investment advisor, accountant, law firm, or regulated financial institution.
- The page implies Rex connects directly to banks, accesses financial institutions independently, moves money, opens accounts, pays bills, files taxes, makes purchases, applies for credit, or executes transactions.
- The page says Clarity is always connected, has real-time balances, complete transaction history, perfect categorization, perfect AI answers, perfect voice transcription, guaranteed uptime, guaranteed deletion, or guaranteed security.
- The page claims `bank-grade`, `military-grade`, `zero-knowledge`, `end-to-end encrypted`, SOC 2, ISO 27001, PCI, HIPAA, formal penetration testing, formal audit status, or similar claims without verification and legal/security review.
- The page exposes API keys, secrets, service account paths, env variable names, database schemas, project IDs, raw logs, internal hostnames, IPs, ports, deployment paths, provider dashboards, or private runbooks.
- The page has no working support/security contact path.

## Implementation Verification

Before publication, verify every Security page claim against the live implementation:

- Public website uses HTTPS.
- Mobile app/backend communication uses secure transport.
- Account connection starts only with user authorization.
- Plaid/account-connection wording matches the actual provider flow.
- User authentication behavior matches live app behavior.
- Account, transaction, budget, goal, conversation, memory/context, and support data are user-scoped as claimed.
- Admin/support access claims match actual operational access.
- Vendor categories match the current stack.
- AI model provider, speech-to-text provider, and text-to-speech provider descriptions match production behavior.
- Voice starts only from user action and is not described as always listening.
- Raw audio, transcripts, generated responses, metadata, prompt/context, and provider retention statements are accurate.
- Account disconnection behavior matches app/support capability.
- Account/data deletion behavior matches app/support capability.
- Backup, log, and retention statements match operational reality.
- Contact/security report paths are monitored.

## Privacy, Terms, And Contact Alignment

The Security page must not contradict:

- `/privacy`
- `/terms`
- `/data-deletion`
- `/contact`
- Public FAQ
- Home page trust sections

Required alignment checks:

- Data categories in Security match Privacy data categories.
- Plaid/account connection language matches Privacy and Terms.
- Rex/AI/voice processing language matches Privacy and Terms.
- Disconnection/deletion language matches Privacy, Terms, and Data Deletion.
- Contact email or contact route matches Privacy, Terms, Data Deletion, Contact, and footer.
- Support warnings about not sending bank passwords, account numbers, SSNs, card numbers, one-time codes, API keys, or secrets are consistent.
- Availability and third-party dependency language matches Terms.

## Plaid Questionnaire Reuse

The Security page may be used as source material for Plaid diligence answers, but the answers must still be reviewed before submission.

Recommended mapping:

- Product purpose and data flow: `security_data_flow.md`
- Access controls: `security_access_controls.md`
- Data in transit/storage: `security_encryption_storage.md`
- Vendors and processors: `security_ai_voice_vendor_handling.md` plus `privacy_sharing_and_vendors.md`
- Retention/deletion: `security_deletion_disconnection.md` plus `privacy_retention_and_deletion.md`
- Incident/security contact: `security_incident_support_language.md`

Rules:

- Do not paste unverified claims into Plaid forms.
- If Plaid asks for exact controls, answer from verified implementation, not aspirational language.
- If a control is planned but not live, say so internally and avoid presenting it as current.

## Placeholder Checklist

Replace before public launch:

- `[last updated date]`
- `[support/contact email]`
- `[security contact email]` if separate
- `[privacy/support email]` if referenced
- `[operator/legal entity]` if included
- Any placeholder vendor list entries
- Any placeholder deletion workflow text
- Any placeholder response expectation or support workflow text

If a placeholder cannot be resolved, the page must remain draft-only.

## Forbidden Public Claims

Avoid these phrases unless formally verified, legally reviewed, and intentionally approved:

- `Plaid-approved`
- `Plaid-backed`
- `Plaid-certified`
- `partnered with Plaid`
- `bank-grade security`
- `military-grade encryption`
- `guaranteed secure`
- `100% private`
- `unhackable`
- `zero-knowledge`
- `end-to-end encrypted`
- `SOC 2 compliant`
- `ISO 27001 certified`
- `PCI compliant`
- `HIPAA compliant`
- `always connected`
- `real-time balances`
- `complete transaction history`
- `perfect categorization`
- `perfect AI`
- `perfect transcription`
- `instant deletion`
- `delete everything automatically`
- `vendors never retain data`
- `Rex connects to your bank`
- `Rex manages your money`

## Required Public Links

The Security page must link to:

- `/privacy`
- `/terms`
- `/data-deletion`
- `/contact`

The footer and relevant landing sections must link back to `/security`.

All links must work on desktop and mobile before using the site for Plaid review.

## Legal And Security Review Flags

Attorney/legal review is required for:

- Legal/operator identity.
- Terms and Privacy alignment.
- Liability-sensitive security wording.
- Incident notification language.
- Jurisdiction-specific privacy rights or security obligations.
- Any formal vulnerability disclosure or safe harbor language.

Security/operator review is required for:

- Vendor list and provider behavior.
- Access-control claims.
- Encryption/storage claims.
- Backup/log/retention claims.
- AI/voice retention and training-use claims.
- Deletion/disconnection workflow.
- Security contact monitoring.

## Final Acceptance Checklist

- All placeholders are replaced or the page remains draft-only.
- No unsupported certifications, guarantees, or absolute security claims remain.
- Vendor/data handling matches backend reality.
- Plaid questionnaire answers can reference the page without contradiction.
- Data flow is user-authorized and high-level.
- Access-control language is verified and not over-specific.
- Encryption/storage language is conservative and vendor-verified where specific.
- AI/voice language distinguishes audio, transcripts, prompts/context, generated responses, spoken responses, and metadata.
- Deletion/disconnection language clearly separates stopping future access from deleting stored Clarity data.
- Security/contact path is real and monitored.
- Privacy, Terms, Data Deletion, Contact, footer, and FAQ are aligned.
- No secrets, internals, dashboard screenshots, logs, hostnames, IDs, keys, tokens, schemas, or private runbooks appear in public copy.
- Clarity is named as the product; Rex is described only as the assistant inside Clarity.
