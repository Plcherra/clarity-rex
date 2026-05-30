# Clarity Privacy Plaid Data Use

Status: File 04 Phase 3 Plaid data use section approved for initial landing launch draft.

Purpose: define clear Privacy Policy language for account connection through Plaid, what data may be received, and how Clarity uses that data.

## Draft Section Title

Preferred:

- `Financial account data and Plaid`

Acceptable alternatives:

- `Account connection through Plaid`
- `Connected financial account information`

Avoid:

- `Plaid partnership`
- `Plaid-approved access`
- `Bank data we collect`

## Plain-Language Summary

Recommended draft:

> If you choose to connect a financial account, Clarity may use Plaid to help establish the connection. Depending on your financial institution, the permissions available, and what you authorize, Clarity may receive account and transaction information that helps power budgeting, categorization, spending review, dashboard summaries, and Rex context.

Optional follow-up:

> Clarity does not ask you to send bank usernames, passwords, account numbers, card numbers, or Social Security numbers through public contact forms or support email.

## What Users Authorize

The policy should explain:

- Users choose whether to connect a financial account.
- The connection flow is provided through Plaid or another reviewed provider if the implementation expands later.
- The data available depends on institution support and user authorization.
- Users can disconnect accounts.
- Users can request deletion of stored Clarity data through the published deletion path.

Avoid saying:

- Clarity can access accounts without permission.
- Clarity receives all possible bank data.
- Plaid endorses or sponsors Clarity.
- Plaid provides Rex or AI features.

## Data That May Be Received

Use permission-based language:

> Depending on your financial institution, permissions, and product configuration, connected account data may include:

Examples:

- Account names or display labels.
- Account type or subtype.
- Institution name or metadata.
- Account identifiers or provider identifiers.
- Available, current, or statement balances where supported.
- Transaction dates, descriptions, merchants, categories, and amounts.
- Pending or posted transaction status where supported.
- Account connection status and related metadata.

Do not claim all users or all institutions provide every field.

## How Clarity Uses Plaid-Connected Data

Recommended use list:

- Organize transactions.
- Categorize spending.
- Show dashboard summaries.
- Calculate budget progress.
- Surface spending pressure or patterns.
- Help Rex answer questions using user-authorized Clarity context.
- Detect duplicates, imports, or account-related inconsistencies where applicable.
- Provide support, security, troubleshooting, and compliance.

Keep wording practical, not magical.

Avoid:

- `automatic money management`
- `guaranteed savings`
- `exact forecasting`
- `real-time balances` unless implementation and provider behavior support that claim.
- `financial advice`

## Rex Context Language

Recommended draft:

> Rex may use connected financial context inside Clarity to answer questions about spending, budgets, goals, and related product context. Rex does not connect directly to banks outside Clarity's user-authorized account connection flow.

This keeps the relationship clear:

- Plaid helps with account connection.
- Clarity stores and organizes authorized product data.
- Rex uses Clarity context to assist the user.

## Disconnection And Deletion Language

Recommended draft:

> You may disconnect connected financial accounts where the app or support flow allows it. You may also request deletion of Clarity data through the Data Deletion page or support contact. Disconnecting an account may stop future access, but stored historical data may remain unless deleted according to Clarity's deletion process.

This must be verified against implementation before publishing.

## Third-Party Policy Link

The Privacy Policy may link to Plaid's privacy-related materials, but should not imply endorsement.

Recommended neutral copy:

> Plaid's own handling of information is described in Plaid's privacy materials.

Before launch:

- Confirm final Plaid privacy link.
- Confirm whether the link should appear in Privacy, Security, FAQ, or all three.

## Plaid-Friendly Boundaries

Use:

- `Clarity uses Plaid to help users connect financial accounts`
- `with your permission`
- `depending on permissions and institution support`
- `account and transaction information`
- `connected financial context`
- `disconnect accounts`
- `request deletion`

Avoid:

- `Plaid endorses Clarity`
- `Plaid-approved`
- `Plaid-backed`
- `bank-grade`
- `we never store financial data`
- `we always receive real-time balances`
- `Rex connects to your bank`

## Acceptance Checklist

- Explains users connect accounts through Plaid.
- Explains connected data depends on permissions, institution support, and configuration.
- Lists account identifiers, balances, transactions, institution metadata, and related account data as examples rather than guaranteed fields.
- Explains use for budgeting, categorization, spending analysis, dashboard summaries, support, and Rex context.
- Avoids Plaid endorsement, sponsorship, or production-approval claims.
- Explains disconnection and deletion paths without overpromising behavior that must be verified later.
