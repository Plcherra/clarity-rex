# Clarity Security Encryption And Storage

Status: File 06 Phase 4 encryption and storage section approved for initial landing launch draft.

Purpose: define public `/security` page language explaining how Clarity protects data in transit and through hosted storage/infrastructure, without overclaiming exact encryption details that depend on vendors or implementation verification.

This contract supports the `/security` page section titled `Encryption and storage`.

## Section Goal

The encryption and storage section should help users and Plaid reviewers understand:

- Clarity uses secure transport for app/site/backend communication where applicable.
- Clarity relies on hosted infrastructure and database/storage providers to operate the product.
- Financial, account, transaction, budget, conversation, memory/context, and support data may be stored to provide product features.
- Exact encryption-at-rest, backup, log, and key-management claims must be verified before publication.

The section should sound practical and honest, not performative.

## Recommended Section Title

Preferred:

- `Encryption and storage`

Acceptable alternatives:

- `How Clarity protects stored and transmitted data`
- `Data protection in transit and storage`
- `Secure transport and hosted storage`

Avoid:

- `Bank-grade encryption`
- `Military-grade security`
- `Unbreakable protection`
- `Certified encryption architecture`

## Plain-Language Summary

Recommended draft:

> Clarity uses secure transport, such as HTTPS/TLS, where data moves between the app, public website, backend services, and service providers. Clarity also relies on hosted infrastructure and database/storage providers to help store and operate product data.

Recommended follow-up:

> Some storage, backup, logging, and encryption-at-rest details depend on the vendors and infrastructure used. Clarity should verify those details before publishing exact technical claims.

## Data In Transit

Recommended copy:

> Clarity should use HTTPS/TLS for public website, app, and backend communication where data is transmitted over the internet.

Must convey:

- Public site should be served over HTTPS.
- App/backend API communication should use secure transport.
- Account connection and vendor communication should use provider-supported secure transport.
- Users should avoid submitting bank credentials, account numbers, or sensitive details through public contact forms.

Do not publish unless verified:

- Exact TLS versions.
- Certificate provider details.
- HSTS preload status.
- Certificate pinning.
- mTLS.
- Private network routing details.

## Data At Rest

Recommended copy:

> Clarity stores product data using hosted infrastructure and database/storage providers. Stored data may include account/profile information, authorized financial account context, transactions, budgets, goals, conversations, memory/context, support requests, logs, and related product records.

Recommended caution:

> Vendor-provided storage protections should be described only after verifying the current provider documentation and production configuration.

Must convey:

- Product data may be stored to provide Clarity features.
- Storage is not limited to live account connections.
- Stored historical data may remain after disconnection unless deletion is requested and processed under the deletion workflow.
- Privacy Policy and Data Deletion pages provide more detail.

Do not claim:

- All fields are encrypted with a specific algorithm unless verified.
- End-to-end encryption unless implemented and reviewed.
- Zero-knowledge storage unless implemented and reviewed.
- Client-side encryption unless implemented and reviewed.
- Exact backup retention unless verified.

## Hosted Infrastructure And Database Providers

Recommended copy:

> Clarity uses service providers for hosting, authentication, database/storage, backend services, and related reliability needs. These providers process information to help operate Clarity, as described in the Privacy Policy.

May mention after verification:

- Provider categories, such as hosting, authentication, database, storage, and backend infrastructure.
- Key provider examples already disclosed in Privacy Policy, such as Supabase, if still accurate.

Avoid:

- Private project IDs.
- Database hostnames.
- Regions unless reviewed and useful.
- Internal deployment paths.
- VPS names, IP addresses, systemd units, or ports.
- Secret names, keys, token names, service account file paths, or env variable values.

## Backups, Logs, And Operational Records

Recommended copy:

> Clarity may keep backups, logs, error reports, security records, and operational data for a limited period as needed to operate, secure, debug, and improve the service.

Must convey:

- Logs and backups may exist.
- Deletion may be subject to backup, legal, security, fraud-prevention, and operational limits.
- This should match `privacy_retention_and_deletion.md`.

Do not publish unless verified:

- Exact backup retention periods.
- Exact log retention periods.
- Exact backup encryption details.
- Exact deletion-from-backup timelines.
- Exact disaster recovery objectives.

## Public Copy Block

This block can be adapted directly for the `/security` page:

> Clarity uses secure transport, such as HTTPS/TLS, where data moves between the app, public website, backend services, and service providers. Clarity also uses hosted infrastructure and database/storage providers to operate the product and store authorized product data.

Optional second paragraph:

> Stored product data may include account/profile information, authorized financial account context, transactions, budgets, goals, conversations, memory/context, support requests, logs, and related records. More detail about data categories, retention, and deletion is available in the Privacy Policy and Data Deletion page.

Optional verification caveat:

> Exact storage, backup, and encryption-at-rest details depend on current vendor configuration and should be verified before publishing detailed technical claims.

## What Not To Expose

Do not include:

- Encryption keys.
- Key-management architecture.
- Secret names.
- Env variable names.
- Service account paths.
- Private certificates.
- Database connection strings.
- Storage bucket names.
- Backup locations.
- Internal logs.
- Private IPs, ports, hostnames, or deployment paths.
- Security-tool screenshots.

Allowed:

- `HTTPS/TLS`
- `secure transport`
- `hosted infrastructure`
- `database/storage providers`
- `backups and logs`
- `Privacy Policy`
- `Data Deletion`

## Plaid-Friendly Wording

Use:

- `secure transport`
- `HTTPS/TLS`
- `hosted infrastructure protections`
- `database/storage providers`
- `authorized product data`
- `backup, legal, security, and operational limits`
- `verify vendor documentation`

Avoid:

- `bank-grade encryption`
- `military-grade encryption`
- `guaranteed secure`
- `perfectly protected`
- `always encrypted everywhere`
- `zero-knowledge`
- `end-to-end encrypted`
- `Plaid-certified security`
- `SOC 2 compliant` unless verified.

## Claims That Require Verification

Do not publish these without verifying the current provider documentation and production configuration:

- Encryption-at-rest algorithms.
- Key-management provider or rotation schedule.
- Field-level encryption.
- End-to-end encryption.
- Client-side encryption.
- Database region or residency claims.
- Backup retention periods.
- Log retention periods.
- Disaster recovery objectives.
- SOC 2, ISO 27001, PCI, HIPAA, or similar certification claims.
- Vendor-specific security-page claims.

## Cross-Links

This section should link to:

- `/privacy` for data categories, vendors, retention, and rights.
- `/data-deletion` for deletion and disconnection details.
- `/contact` for privacy or security questions.

Optional:

- `/terms` for service availability and third-party dependency boundaries.

## Implementation Review Questions

Before publishing, verify:

- Does the public site use HTTPS?
- Does mobile app/backend communication use HTTPS/TLS?
- Which providers store production data?
- Which provider docs support any encryption-at-rest copy?
- What categories of logs/backups exist?
- Are exact retention periods known and safe to publish?
- Does deletion language align with backup and operational constraints?
- Does this section avoid exposing private infrastructure details?

## Acceptance Checklist

- Mentions HTTPS/TLS or secure transport for data in transit.
- Mentions hosted database/storage protections only where accurate.
- Explains product data may be stored to provide Clarity features.
- Cross-links Privacy and Data Deletion.
- Avoids unsupported encryption, certification, backup, and key-management details.
- Flags vendor-dependent claims for verification before launch.
