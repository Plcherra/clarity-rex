# Plaid Questionnaire Prep

Status: File 10 Phase 3 Plaid questionnaire prep complete.

## Purpose

This document prepares conservative, public-page-aligned answers for Plaid risk and security diligence. It is not the final Plaid submission package; that comes after deployment, live URL verification, and FormSubmit testing.

Use this document to answer Plaid questions consistently without inventing unsupported claims.

## Public URLs To Use After Deployment

Use these URLs after the site is deployed and verified:

- Public site: `https://rexpilot.com/`
- Privacy Policy: `https://rexpilot.com/privacy`
- Terms of Service: `https://rexpilot.com/terms`
- Security and Data Handling: `https://rexpilot.com/security`
- Data Deletion: `https://rexpilot.com/data-deletion`
- Contact: `https://rexpilot.com/contact`

Do not submit these URLs until File 10 Phase 5 production deployment and Phase 6 live smoke testing are complete.

## Product Summary

Suggested answer:

> Clarity is a personal AI financial co-pilot that helps users understand spending, budgets, goals, and financial context. Rex is the assistant inside Clarity. Users can review financial activity, organize budgets and categories, maintain goals, and ask Rex questions about their own financial context. Clarity is not a bank, broker, lender, investment advisor, tax advisor, accountant, law firm, or credit counselor.

Public source:

- Home: `/`
- Privacy: `/privacy`
- Terms: `/terms`

## Plaid Use Case

Suggested answer:

> Clarity uses user-authorized account connections through providers such as Plaid so users can connect financial accounts and view account/transaction context inside Clarity. Connected data may support spending views, budgets, cash-flow context, categories, goals, and Rex assistant responses. Clarity does not ask for or store bank login credentials.

Public source:

- Privacy: `/privacy`
- Terms: `/terms`
- Security: `/security`

## Requested Data Categories

Expected categories to describe, depending on the exact Plaid product configuration:

- Account metadata, such as account name/type and institution context.
- Balance information, where available.
- Transaction history, where available.
- Transaction details needed for categorization, budgeting, spending summaries, and assistant context.
- Connection metadata needed to maintain account access and troubleshoot user-authorized connections.

Suggested answer:

> Clarity requests only the account and financial data needed to provide the user-facing features selected by the user, such as accounts, balances, transactions, spending summaries, budgets, categories, goals, and assistant context. Available fields depend on the user's institution, permissions, provider behavior, and product configuration.

Public source:

- Privacy: `/privacy`
- Security: `/security`

## User Consent And Control

Suggested answer:

> Account connection is user-authorized. Users choose when to connect accounts. Clarity does not describe Plaid as a bank and does not ask users to enter bank login credentials into Clarity forms. Users can request help with disconnection or deletion through the published Data Deletion and Contact paths.

Public source:

- Privacy: `/privacy`
- Terms: `/terms`
- Data Deletion: `/data-deletion`
- Contact: `/contact`

## Data Use

Suggested answer:

> Clarity uses connected or imported financial data to provide product features such as account views, transaction review, spending summaries, budgets, categories, goals, and Rex assistant responses. Clarity may also use information to respond to support requests, verify deletion/privacy requests, prevent abuse, troubleshoot issues, maintain reliability, and improve the product. Clarity does not sell personal financial data.

Public source:

- Privacy: `/privacy`

## AI And Rex Assistant Boundary

Suggested answer:

> Rex is the assistant inside Clarity. Rex may process user messages, generated responses, approved memory, goals, voice transcripts, conversation metadata, and related financial context to personalize assistance. Rex does not independently connect to banks, move money, pay bills, open accounts, apply for credit, file taxes, make purchases, or execute transactions.

Public source:

- Privacy: `/privacy`
- Terms: `/terms`
- Security: `/security`

## Security Posture

Suggested answer:

> Clarity is designed around user authorization, secure transport patterns, managed infrastructure, user-scoped product data, limited operational access, and clear support/security contact paths. Public copy avoids unsupported claims such as formal certifications, bank-grade security, or absolute security guarantees unless those claims are formally verified and intentionally published.

Public source:

- Security: `/security`

## Vendors And Processors

Suggested answer:

> Clarity may use service providers for account connections, hosting, databases, AI model responses, speech-to-text, text-to-speech, support/contact forms, email delivery, security, monitoring, and analytics if enabled. Providers may process information according to their own terms, privacy policies, security practices, and legal obligations.

Public source:

- Privacy: `/privacy`
- Security: `/security`

## Retention, Deletion, And Disconnection

Suggested answer:

> Disconnecting a financial account may stop future access where supported. Data already stored in Clarity may remain until the user deletes it through supported product controls or submits a deletion request. Some records may remain for a limited period in backups, logs, security records, support records, or systems where retention is needed for legal, fraud-prevention, security, dispute-resolution, or operational reasons.

Public source:

- Privacy: `/privacy`
- Security: `/security`
- Data Deletion: `/data-deletion`

## Support And Security Contact

Suggested answer:

> Users can contact Clarity for product questions, beta access, privacy requests, data deletion, or security concerns through the Contact page or by emailing `clarity.rex@gmail.com`. Public forms warn users not to include bank passwords, account numbers, card numbers, Social Security numbers, one-time codes, API keys, screenshots, CSV files, or other sensitive financial details.

Public source:

- Contact: `/contact`
- Data Deletion: `/data-deletion`
- Security: `/security`

## Things Not To Claim

Do not claim:

- Plaid approval, endorsement, certification, sponsorship, or partnership.
- Attorney-reviewed legal pages.
- Bank-grade or military-grade security.
- Perfect security, perfect AI, perfect categorization, guaranteed savings, guaranteed outcomes, or guaranteed deletion.
- Real-time bank data or complete transaction history.
- That Clarity stores bank login credentials.
- That Rex can move money, open accounts, file taxes, apply for credit, or take financial actions for users.
- That connected data is always available or always current.

## Open Verification Items Before Submission

Complete these before final Plaid submission:

- Deploy production site to `https://rexpilot.com`.
- Verify all public URLs return 200 over HTTPS.
- Submit live waitlist/contact tests.
- Confirm FormSubmit delivery to `clarity.rex@gmail.com`.
- Confirm any FormSubmit activation email if prompted.
- Verify redirect to `https://rexpilot.com/form-success`.
- Confirm the exact Plaid products/data scopes requested in the Plaid dashboard.
- Confirm current production vendor list and provider behavior.
- Confirm legal-review status remains visible internally.

## Acceptance Decision

File 10 Phase 3 passes. The Plaid questionnaire prep is aligned with public pages and ready to be converted into the final submission package after deployment and live smoke testing.
