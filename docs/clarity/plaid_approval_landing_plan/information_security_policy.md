# Clarity Information Security Policy

Version: 1.0  
Effective date: May 30, 2026  
Owner: Pedro Martins, Founder  
Application: Clarity, including Rex, the AI financial co-pilot

## 1. Introduction

### Company

Clarity is an early-stage personal AI financial co-pilot mobile application developed and operated by Pedro Martins as a solo founder. Clarity helps users understand their spending, budgets, goals, and financial context through a mobile app and an AI assistant named Rex.

Clarity is currently preparing for Plaid Production access. This policy describes Clarity's current information security practices, the intended security baseline for production use, and the controls that will mature as the company grows.

Clarity is not a bank, broker, lender, investment advisor, tax advisor, accountant, law firm, or credit counselor. Clarity does not move money, execute transactions, open accounts, apply for credit, or make financial decisions on behalf of users.

### Purpose

The purpose of this Information Security Policy is to define how Clarity protects user data, financial account data, application systems, credentials, and supporting infrastructure. The policy is intended to:

- Establish clear security expectations for Clarity's production environment.
- Protect user-authorized financial data received through Plaid.
- Protect authentication, application, and AI-assistant data handled by Clarity.
- Support Plaid Production access review and related compliance diligence.
- Provide a realistic security governance baseline for an early-stage, solo-founder product.
- Define future improvement areas as Clarity grows.

### Scope

This policy applies to:

- The Clarity mobile application.
- Rex, the AI assistant experience inside Clarity.
- Backend services, APIs, serverless functions, and databases used by Clarity.
- Supabase authentication, database, storage, and related managed services used by Clarity.
- Plaid integrations used for user-authorized account connections.
- AI and supporting providers, including Grok or other model providers used to power Rex.
- Source code repositories, development tools, deployment workflows, environment variables, credentials, and operational logs.
- Support, privacy, security, and data deletion workflows.

This policy applies to Pedro Martins in his role as founder, developer, administrator, and operator of Clarity. If contractors or employees are added later, they will be required to follow this policy or a successor policy before receiving access to Clarity systems or user data.

## 2. Information Security Objectives

Clarity's security program is designed around practical controls that match the product's current stage while protecting sensitive user information with care. Clarity's security objectives are:

- Protect user-authorized financial data from unauthorized access, disclosure, alteration, or loss.
- Avoid collecting or storing data that is not needed for the product's stated functionality.
- Use Plaid for bank account connection flows so Clarity does not collect or store users' bank usernames or passwords.
- Authenticate users before allowing access to private product data.
- Scope user data so users can access only their own Clarity records.
- Use secure transport, including HTTPS/TLS, for application, backend, and provider communications.
- Use managed infrastructure and database protections, including Supabase authentication, row-level security where applicable, and provider-supported encryption at rest.
- Treat secrets, Plaid tokens, service keys, and production credentials as restricted information.
- Limit internal access to user data to operational, support, security, compliance, and user-requested purposes.
- Maintain a clear process for responding to security incidents, vulnerabilities, and user security reports.
- Review and improve the security program as the product matures.

Clarity acknowledges that, as an early-stage solo-founder application, it does not yet have enterprise-scale security operations such as a dedicated 24/7 security team, formal SOC 2 certification, or a mature vendor-risk department. This policy intentionally avoids claiming controls that are not yet implemented. Clarity's near-term objective is to operate with disciplined, transparent, and appropriate safeguards while building toward more formal security processes over time.

## 3. Data Classification and Handling

Clarity classifies information based on sensitivity and risk. These classifications guide access, storage, transmission, and incident-response decisions.

### Public Information

Public information is intended for general availability and may be published on Clarity's website, app store listings, public documentation, or marketing materials.

Examples include:

- Public website content.
- General product descriptions.
- Public privacy, terms, security, and data deletion pages.
- Non-sensitive support instructions.

Public information should still be reviewed for accuracy. Clarity should not make unsupported claims about Plaid approval, bank-grade security, certifications, legal review, or financial outcomes.

### Internal Information

Internal information is used to operate and develop Clarity but is not intended for public release.

Examples include:

- Product plans and roadmaps.
- Non-sensitive internal documentation.
- Non-production configuration notes.
- Testing notes that do not include real user data.

Internal information should be stored in approved repositories, documentation systems, or founder-controlled accounts. It should not be published unless reviewed.

### Confidential Information

Confidential information includes user and business information that could create privacy, security, or business risk if disclosed.

Examples include:

- User profile information.
- User email addresses.
- Budget, goal, transaction categorization, and app preference data.
- Conversation history with Rex.
- User support requests.
- Product analytics or operational logs tied to user behavior.
- Vendor contracts, billing records, and non-public operational details.

Confidential information must be accessed only for legitimate product, support, security, compliance, debugging, or user-requested purposes.

### Restricted Information

Restricted information is the most sensitive category and requires the strongest handling available within Clarity's current architecture.

Examples include:

- Plaid access tokens, item identifiers, account identifiers, and related connection metadata.
- User-authorized financial account and transaction data received through Plaid.
- Authentication records and session-related information.
- Supabase service-role keys or other privileged backend credentials.
- API keys for Plaid, Supabase, Grok, AI services, speech services, email providers, monitoring tools, deployment systems, and app store systems.
- Production database credentials.
- Security incident records.
- Vulnerability details before remediation.

Restricted information must not be placed in public repositories, public issue trackers, screenshots, support forms, chat messages, or unapproved documents. Secrets must be stored in environment variables, provider secret stores, or other appropriate secret-management mechanisms rather than hardcoded into source code.

### Plaid Financial Data Handling

Clarity uses Plaid to help users connect financial accounts with their permission. Clarity does not ask users to provide bank usernames or passwords directly to Clarity, and Clarity does not store bank login credentials.

Depending on the user's institution, permissions, Plaid product configuration, and available data, Clarity may receive and process financial account data such as:

- Institution names or institution metadata.
- Account names, display labels, types, or subtypes.
- Account identifiers or provider identifiers.
- Available, current, or statement balances where supported.
- Transaction dates, descriptions, merchants, categories, and amounts.
- Pending or posted transaction status where supported.
- Account connection status, item metadata, and related troubleshooting information.

Clarity uses this data to provide user-facing functionality such as budgeting, spending insights, categorization, dashboard summaries, goals, financial coaching, and Rex assistant context. Clarity may also use this data for support, troubleshooting, security, abuse prevention, compliance review, and product reliability.

Plaid-connected data must be handled as Restricted Information. It should be stored only where needed to operate the product, should be scoped to the authorized user, and should not be used for unrelated advertising or sold as personal financial data.

### AI Assistant Data Handling

Rex is the AI assistant inside Clarity. To provide AI-powered responses, Clarity may send relevant prompts, conversation content, approved product context, authorized financial context, and related metadata to AI model providers such as Grok.

Clarity should send only the context reasonably needed to provide the requested assistant feature. Rex may help users understand spending, budgets, goals, and related product context, but Rex does not independently connect to banks, move money, open accounts, apply for credit, file taxes, or execute financial actions.

AI-related prompts, responses, transcripts, memory, and conversation context are Confidential or Restricted depending on whether they include financial or sensitive account information.

### Retention and Deletion

Clarity should retain information only as long as reasonably needed to provide the product, support users, comply with legal or platform requirements, maintain security, resolve disputes, debug issues, or preserve operational records.

Disconnecting a financial account may stop future access to that account where supported, but stored historical data may remain unless deleted through product controls or a data deletion request. Some data may remain for a limited period in backups, logs, security records, support records, or systems where retention is needed for legal, fraud-prevention, security, dispute-resolution, or operational reasons.

Clarity will maintain a published contact or data deletion path for users who want help deleting account data.

## 4. Access Control and Authentication

### User Authentication

Users access Clarity through authenticated accounts. Clarity uses Supabase Auth and OAuth or provider-supported authentication flows where applicable. Private user data should be available only after successful authentication.

Users are responsible for maintaining control of their devices, email accounts, and login credentials. Clarity support channels must not ask users to send bank passwords, full account numbers, full card numbers, Social Security numbers, one-time login codes, API keys, or private secrets.

### User-Scoped Access

Clarity is designed so each user's product data is scoped to that user. Account records, transactions, budgets, goals, Rex conversations, memory/context, and related records should be associated with the authenticated user who owns or is authorized to use that data.

Supabase Row Level Security (RLS) should be enabled and used for tables that contain user-scoped data. Database policies should restrict user access to only the records they are permitted to view or modify. Backend services that require elevated privileges must be implemented carefully and limited to defined use cases.

### Founder and Administrative Access

Because Clarity is currently operated by a solo founder, Pedro Martins may hold administrative access to production systems, vendor dashboards, code repositories, and support channels. Administrative access is permitted only for legitimate purposes, including:

- Operating and maintaining Clarity.
- Investigating and resolving user support requests.
- Debugging product issues.
- Responding to privacy or deletion requests.
- Investigating suspicious activity or security reports.
- Performing compliance, Plaid review, and operational duties.

Administrative access must not be used for casual browsing of user data. Access should be minimized as the product matures, and additional role separation should be introduced when employees or contractors join.

### Credential and Secret Management

Production credentials, API keys, access tokens, and service-role secrets must be treated as Restricted Information.

Clarity will:

- Avoid hardcoding secrets into source code.
- Avoid committing secrets to public or shared repositories.
- Store secrets in environment variables, deployment secrets, Supabase secret configuration, or other appropriate managed secret stores.
- Rotate credentials if exposure is suspected.
- Use separate credentials for development, staging, and production where supported.
- Avoid exposing Plaid access tokens or backend service credentials to the mobile client.

### Plaid Token Handling

Plaid access tokens and related identifiers must be stored server-side and treated as Restricted Information. They should be used only to retrieve and maintain user-authorized data for Clarity features. Clarity should not expose Plaid access tokens in client logs, frontend error messages, screenshots, public support requests, or analytics events.

If a user disconnects an account or requests deletion, Clarity should follow the applicable provider flow and internal deletion process for the related account connection and stored data.

### Multi-Factor Authentication and Account Security

Where available, Clarity administrative accounts should use strong authentication and multi-factor authentication, especially for Plaid, Supabase, source code hosting, deployment platforms, app stores, email, and domain/DNS accounts.

As Clarity grows, access reviews should be formalized to confirm that only authorized personnel have access to production systems and sensitive data.

## 5. Data Encryption

### Data in Transit

Clarity uses HTTPS/TLS for data transmitted between users, the mobile app, backend services, hosted infrastructure, and service providers where data is sent over the internet. Production endpoints should use valid certificates and should not rely on self-signed certificates.

Secure transport applies to:

- Mobile app communication with backend services.
- Website and public policy pages.
- Supabase-hosted services.
- Plaid API communication.
- AI provider communication.
- Support, monitoring, deployment, and operational service communication where applicable.

Sensitive information should not be sent through insecure channels or public support forms. Users should be warned not to send bank credentials, full account numbers, full card numbers, Social Security numbers, one-time codes, API keys, or private secrets through public forms or email.

### Data at Rest

Clarity uses managed infrastructure providers, including Supabase, to store application data. Supabase and other managed providers provide platform-level security and encryption capabilities for stored data. Clarity relies on those providers' current security practices and production configuration for encryption at rest, backups, and infrastructure-level protections.

Stored product data may include user profiles, authorized account context, transaction data, budgets, goals, conversation history, Rex memory/context, support records, logs, and related operational records.

Clarity should not claim end-to-end encryption, zero-knowledge storage, field-level encryption, or a specific encryption algorithm unless those controls are implemented, verified, and documented. As Clarity matures, additional field-level protection may be considered for particularly sensitive values.

### Backups, Logs, and Operational Records

Backups, logs, error reports, and operational records may be maintained by Clarity or its service providers to operate, secure, debug, and improve the service. These records should be limited to operational need and protected according to their sensitivity.

Logs should avoid unnecessary collection of Plaid access tokens, API keys, bank credentials, full account numbers, full card numbers, Social Security numbers, or other secrets. If sensitive data is accidentally logged, Clarity should treat that as a security issue, remove or restrict the data where feasible, and rotate affected credentials if needed.

## 6. Third-Party Management

Clarity relies on third-party service providers to operate the product. As an early-stage company, Clarity's vendor management process is lightweight but intentional. Vendors should be selected based on product need, security posture, reliability, data handling practices, and ability to support Clarity's obligations to users and platform partners.

### Key Providers

Current or expected providers include:

- Plaid: financial account connection and user-authorized account/transaction data access.
- Supabase: authentication, database, storage, backend services, and related managed infrastructure.
- Grok or other AI model providers: AI assistant responses and reasoning for Rex.
- Speech-to-text or text-to-speech providers, if voice features are enabled.
- App store and mobile platform providers.
- Hosting, domain, email, monitoring, analytics, and support/contact providers as needed.

Provider names and use may evolve. Public privacy and security disclosures should be updated when material provider categories or data-sharing practices change.

### Vendor Data Handling Expectations

Clarity should use third-party providers only for purposes needed to provide, secure, support, or improve the product. Providers may process information according to their own terms, privacy policies, security practices, and legal obligations.

Clarity should avoid sending more data to providers than is reasonably needed for the feature being used. For example, AI model requests should include only the user message and relevant Clarity context needed to answer the user's request. Support tools should not receive raw financial data unless necessary for support and disclosed appropriately.

### Plaid Relationship

Clarity uses Plaid to help users connect financial accounts. Plaid provides the connection experience and access to user-authorized financial data according to the permissions granted by the user and supported by the user's institution.

Clarity does not represent that Plaid sponsors, endorses, certifies, or approves Clarity unless that is formally true and authorized. Clarity will follow Plaid's applicable production, launch, and data-use requirements as part of the Production access process.

### Vendor Review

Before adding a new provider that will process Confidential or Restricted Information, Clarity should review:

- What data the provider will process.
- Why the provider is needed.
- Whether the provider is reputable and appropriate for the data involved.
- Available security and privacy documentation.
- Whether the provider supports HTTPS/TLS and secure authentication.
- Data retention, deletion, and training-use practices where relevant.
- Whether the provider introduces new user-facing disclosures.

As Clarity grows, this lightweight review should evolve into a formal vendor inventory and vendor-risk review process.

## 7. Incident Response Plan

Clarity maintains a practical incident response process appropriate for a solo-founder operation. A security incident is any actual or suspected event that could compromise the confidentiality, integrity, or availability of Clarity systems or data.

Examples include:

- Unauthorized access to user data.
- Exposure of Plaid tokens, API keys, service-role keys, or production credentials.
- Accidental publication of Restricted Information.
- Unauthorized database access or suspicious administrative activity.
- Vulnerability exploitation.
- Loss or compromise of a founder device or account with production access.
- Misconfigured storage, database rules, or RLS policies that expose user data.
- Provider breach notification affecting Clarity data.

### Incident Response Roles

Pedro Martins is currently responsible for incident response, including detection, triage, containment, remediation, user or provider communication, and post-incident review. If employees or contractors are added, incident response roles will be assigned and documented.

### Response Steps

Clarity's incident response process includes the following steps:

1. Identify and triage  
   Determine what happened, what systems or data may be affected, when the event started, and whether user data, Plaid data, credentials, or production systems are involved.

2. Contain  
   Limit further exposure or damage. This may include disabling affected keys, revoking sessions, restricting database access, disabling a vulnerable feature, pausing a deployment, removing exposed data, or contacting a provider.

3. Preserve evidence  
   Preserve relevant logs, timestamps, screenshots, provider notices, error reports, support messages, and deployment history where available. Evidence should be stored securely and not published.

4. Eradicate and remediate  
   Fix the root cause. This may include patching code, updating RLS policies, rotating secrets, changing access permissions, updating infrastructure settings, or deploying a corrected release.

5. Recover  
   Restore normal operation after confirming the issue has been addressed. Monitor for recurrence and verify that affected systems are functioning as expected.

6. Notify as appropriate  
   Determine whether user, vendor, platform, legal, or regulatory notification is required. If Plaid-connected data or Plaid credentials are involved, Clarity should notify Plaid through the appropriate support or account channel as required by applicable agreements or instructions.

7. Review and improve  
   Document what happened, the impact, the response, and follow-up actions. Update this policy, code, monitoring, documentation, or controls where needed.

### Security Contact and Vulnerability Reports

Clarity will maintain a published contact path for users and researchers to report security concerns. Reports should include a clear description, affected feature or page, safe reproduction steps if available, and non-sensitive contact information for follow-up.

Reporters should not access, copy, publish, or share data they are not authorized to use. Clarity does not currently operate a formal bug bounty program and should not promise rewards, safe harbor terms, or specific response-time guarantees unless those programs are formally established.

## 8. Vulnerability Management and Patching

Clarity's vulnerability management process is designed to be realistic for a small, early-stage product while reducing avoidable security risk.

### Dependency Updates

Clarity will review and update application dependencies on a regular basis, including Flutter packages, Supabase client libraries, backend libraries, Plaid SDKs or API clients, AI provider SDKs, and build/deployment dependencies.

Security-related updates should be prioritized based on severity, exploitability, exposure, and whether the affected component is used in production. Critical security patches should be applied as soon as reasonably possible after review and testing.

### Code Review and Testing

As a solo-founder project, code review may initially be self-review. Before production deployment, security-sensitive changes should be reviewed carefully, especially changes involving:

- Authentication and session handling.
- Supabase RLS policies or database permissions.
- Plaid token exchange, storage, or account connection logic.
- Data deletion or disconnection workflows.
- AI context selection and prompt construction involving financial data.
- Logging, analytics, or monitoring.
- Environment variables and secret handling.

Where practical, Clarity should use automated tests, manual QA, static analysis, dependency scanning, and provider dashboard checks to identify regressions before production release.

### Configuration Review

Clarity should periodically review production configuration for:

- Supabase RLS coverage on user-scoped tables.
- Production environment variables and secret storage.
- Plaid dashboard settings and product scopes.
- HTTPS/TLS configuration for public endpoints.
- Redirect URLs, callback URLs, OAuth settings, and app identifiers.
- Admin account access and multi-factor authentication.
- Logging and analytics settings to avoid unnecessary sensitive data collection.

### Vulnerability Remediation Targets

Because Clarity is early-stage, remediation targets are practical guidelines rather than formal service-level agreements:

- Critical vulnerabilities affecting production user data or credentials should be investigated immediately and remediated as soon as feasible.
- High-risk vulnerabilities should be prioritized ahead of feature work.
- Medium and low-risk vulnerabilities should be tracked and addressed based on risk and engineering capacity.
- Issues involving exposed secrets should trigger credential rotation, exposure review, and repository or log cleanup where feasible.

## 9. Employee and Contractor Security

Clarity is currently operated by a solo founder, Pedro Martins. There are no employees or regular contractors with production access at the time of this policy.

### Solo Founder Responsibilities

The founder is responsible for:

- Maintaining secure access to Clarity systems and vendor accounts.
- Using strong passwords and multi-factor authentication where available.
- Protecting founder devices used for development and administration.
- Avoiding storage of production secrets in plaintext notes, screenshots, or public repositories.
- Keeping local development tools, operating systems, and dependencies reasonably updated.
- Separating development, test, and production data where practical.
- Handling user data only for legitimate product, support, security, compliance, or user-requested purposes.
- Monitoring support and security contact paths.

### Future Employees or Contractors

If Clarity adds employees, contractors, advisors, or vendors with access to systems or user data, Clarity will establish additional controls before granting access, including:

- Role-based access appropriate to the person's responsibilities.
- Least-privilege access to production systems.
- Confidentiality obligations or written agreements where appropriate.
- Security onboarding covering this policy, data handling, credentials, support boundaries, and incident reporting.
- Access removal when the relationship ends or access is no longer needed.
- Periodic access review.

Contractors should not receive production data or production access unless necessary and approved by the founder. Test data or synthetic data should be used when possible.

## 10. Policy Review and Maintenance

This policy will be reviewed at least annually and whenever material changes occur, including:

- Plaid Production access approval or major Plaid integration changes.
- New categories of financial data collection.
- New AI, speech, analytics, support, or infrastructure providers that process user data.
- Significant changes to authentication, database access, RLS policies, or backend architecture.
- A security incident or near miss.
- Addition of employees, contractors, or new administrative users.
- New legal, platform, or vendor requirements.

The founder is responsible for maintaining this policy and ensuring it remains accurate. Public-facing privacy, security, terms, and data deletion pages should be updated when this policy changes in a way that affects users.

### Planned Security Program Improvements

As Clarity matures, planned improvements may include:

- More formal access reviews.
- Documented vendor inventory and vendor-risk review.
- Expanded security logging and alerting.
- More automated dependency and secret scanning.
- Formal backup and disaster recovery documentation.
- More granular data retention schedules.
- Additional field-level protection for highly sensitive values if warranted.
- External security review or penetration testing when product scale and risk justify it.
- Formal employee and contractor onboarding processes.
- SOC 2 or similar security framework evaluation if commercially appropriate.

These items are future roadmap goals and should not be represented as completed controls until implemented.

## 11. Approval

This Information Security Policy is approved by the founder of Clarity and is effective as of the date listed above.

Founder: Pedro Martins  
Title: Founder, Clarity  
Signature: ______________________________  
Date: ______________________________

## PDF Conversion Note

To turn this Markdown document into a PDF, open it in a Markdown editor that supports export to PDF, such as VS Code with a Markdown PDF extension, Typora, Obsidian, or Google Docs. Alternatively, use Pandoc from the repository root:

```bash
pandoc docs/clarity/plaid_approval_landing_plan/information_security_policy.md -o Clarity_Information_Security_Policy.pdf
```

Before submitting the PDF, review the final formatting, fill in the approval date and signature, and confirm that the provider list and security claims still match the current production implementation.
