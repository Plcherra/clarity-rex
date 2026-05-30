# Clarity Terms Plaid Connection

Status: File 05 Phase 5 Plaid connection terms approved for initial landing launch draft.

## Purpose

This contract defines the Terms of Service language for connecting financial accounts through Plaid or another reviewed provider. It should make user authorization, third-party availability, data limits, and disconnection paths clear.

The Terms should not promise continuous connectivity, real-time balances, complete transaction coverage, or Plaid endorsement.

## Draft Section Titles

Preferred:

- `Connected financial accounts`

Acceptable alternatives:

- `Account connections`
- `Financial account connections`
- `Connecting accounts through Plaid`

Avoid:

- `Plaid partnership`
- `Plaid-approved connection`
- `Bank account management`
- `Real-time bank access`

## User Authorization

Recommended draft:

> If you choose to connect a financial account, you authorize Clarity and its service providers, including Plaid where applicable, to access and use account information you make available through the connection flow to provide Clarity.

Required meaning:

- Users choose whether to connect accounts.
- Account connection is permission-based.
- Clarity does not ask users to email or submit bank passwords through public forms.
- Connected data is used to provide Clarity features.

## Provider And Institution Availability

Recommended draft:

> Account connection features depend on third-party providers, financial institutions, provider availability, institution support, permissions, network conditions, and product configuration. Connected data may be delayed, incomplete, unavailable, or inaccurate.

This protects against:

- Assuming all institutions work.
- Assuming continuous connectivity.
- Assuming complete transaction history.
- Assuming real-time balances.
- Assuming all Plaid fields are always available.

## Data That May Be Available

Recommended draft:

> Depending on your financial institution, permissions, and product configuration, connected data may include account details, balances, transactions, institution information, connection status, and related metadata.

Use `may include` language. Do not say Clarity receives all possible bank data.

## How Clarity Uses Connected Data

Recommended draft:

> Clarity uses connected data to organize transactions, support budgeting, show dashboard summaries, provide spending context, troubleshoot account-related issues, and help Rex answer questions using authorized Clarity context.

This should align with Privacy and Security pages.

## User Responsibility

Recommended draft:

> You should only connect accounts that belong to you or that you are authorized to use with Clarity. You are responsible for the accuracy of information you provide and for reviewing information shown in Clarity before relying on it.

This pairs with Phase 2 account responsibilities.

## Disconnection And Deletion

Recommended draft:

> You may disconnect connected accounts where the app or support flow allows it. Disconnecting an account may stop future access through that connection, but it may not automatically delete historical information already stored in Clarity. You may request deletion through the Data Deletion page or support contact.

Required links:

- `/data-deletion`
- `/contact`
- `/privacy`

## Third-Party Terms

Recommended draft:

> Plaid, financial institutions, app stores, device platforms, and other third-party services may have their own terms, privacy policies, availability limits, and security practices. Clarity does not control those third-party services.

This should stay neutral and avoid blaming providers while making dependency clear.

## Forbidden Claims

Do not say:

- `Plaid endorses Clarity`
- `Plaid-approved`
- `Plaid-backed`
- `Plaid-certified`
- `bank-grade`
- `always connected`
- `real-time balances`
- `complete transaction history`
- `we never store financial data`
- `Rex connects directly to your bank`
- `Rex manages your money`

## Cross-Page Alignment

The connected-account Terms must align with:

- `plaid_consent_placement_contract.md`
- `privacy_plaid_data_use.md`
- `privacy_data_categories.md`
- `privacy_retention_and_deletion.md`
- `privacy_user_rights_and_choices.md`
- `terms_eligibility_accounts.md`
- `terms_ai_assistant_disclaimer.md`
- `public_faq_contract.md`

If the Plaid implementation changes, review all of these files together.

## Launch Review Questions

Resolve before publishing final Terms:

- Is Plaid the only account-connection provider at launch?
- Does the app expose self-serve disconnect, support-driven disconnect, or both?
- What happens to Plaid items/tokens when an account is disconnected?
- Does account disconnection delete historical transaction data, or only stop future access?
- Are imported CSV accounts covered by the same terms or a separate import section?
- What final contact route should users use for connected-account issues?

## Acceptance Checklist

- States users authorize account connections.
- States connected-account availability depends on financial institutions, Plaid/provider behavior, permissions, network conditions, and product configuration.
- States connected data may be delayed, incomplete, unavailable, or inaccurate.
- States users can disconnect accounts where supported.
- Explains disconnecting does not necessarily delete historical Clarity data unless deletion is requested or implementation later guarantees it.
- Links conceptually to Privacy, Data Deletion, and Contact pages.
- Avoids Plaid endorsement, continuous connectivity, real-time balance, or complete-data promises.

