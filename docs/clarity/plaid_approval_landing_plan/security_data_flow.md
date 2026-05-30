# Clarity Security Data Flow

Status: File 06 Phase 2 data flow explanation approved for initial landing launch draft.

Purpose: define a public, Plaid-friendly explanation of how user-authorized data moves through Clarity without exposing implementation internals, secrets, network details, or private infrastructure.

This contract supports the `/security` page section titled `How data moves through Clarity`.

## Section Goal

The data-flow section should help users and Plaid reviewers understand:

- Account connection starts with user authorization.
- Plaid helps establish supported financial account connections.
- Clarity stores and organizes authorized product data.
- The mobile app displays summaries, budgets, transactions, and account context.
- Rex may use approved Clarity context to answer user questions.
- Users can disconnect accounts or request deletion through published paths.

The section should avoid detailed engineering internals that are not needed for public trust review.

## Recommended Section Title

Preferred:

- `How data moves through Clarity`

Acceptable alternatives:

- `How Clarity handles connected account data`
- `From consent to product context`
- `Data flow at a glance`

Avoid:

- `Backend architecture`
- `Database flow`
- `How we access your bank`
- `Rex bank connection`

## Plain-Language Summary

Recommended draft:

> Clarity only uses connected financial context after you choose to connect an account. When supported, Plaid helps establish the connection between your financial institution and Clarity. Clarity then uses authorized account and transaction context to power dashboard summaries, budgets, categorization, account views, and Rex conversations inside the product.

Optional follow-up:

> The exact data available depends on your financial institution, permissions, and product configuration.

## Public Data Flow Diagram

Use a simple text or visual diagram like this:

```text
You authorize a connection
        |
        v
Plaid helps connect supported financial accounts
        |
        v
Clarity receives authorized account and transaction context
        |
        v
Clarity organizes product data for dashboards, budgets, and account views
        |
        v
Rex may use approved Clarity context when answering your questions
```

Design note:

- If this becomes a visual section, use simple labeled steps or cards.
- Do not use network diagrams, database icons with table names, endpoint names, keys, tokens, IPs, or private service names.

## Step-By-Step Public Explanation

### 1. User Authorization

Recommended copy:

> You choose whether to connect a financial account. Clarity should explain why connected account context is useful before asking for access.

Must convey:

- Account connection is optional unless a specific feature requires it.
- Users control whether to start the connection flow.
- Users should not send bank credentials or account numbers through public contact forms.

### 2. Account Connection Provider

Recommended copy:

> When you connect an account, Clarity may use Plaid to help establish a supported connection with your financial institution.

Must convey:

- Plaid is a service provider for account connection.
- Plaid is not Rex.
- Plaid does not endorse, sponsor, or provide Clarity's AI features.
- Provider and institution availability may vary.

### 3. Authorized Data Received By Clarity

Recommended copy:

> Depending on permissions, institution support, and product configuration, Clarity may receive account labels, account type, institution information, balances where available, transactions, merchant descriptions, categories, dates, amounts, and connection metadata.

Must convey:

- The list is permission-based and example-driven.
- Not every account or institution provides every field.
- Avoid claiming continuous or real-time access unless verified.

### 4. Product Storage And Organization

Recommended copy:

> Clarity stores and organizes authorized product data so the app can show dashboards, budgets, transaction history, account summaries, categorization, and related support information.

Must convey:

- Clarity may store historical product data after import or connection.
- Disconnecting an account may stop future access but may not automatically delete stored historical data unless deletion is requested.
- The deletion path is described on `/data-deletion`.

### 5. App Display

Recommended copy:

> The Clarity app uses organized product data to display financial summaries, budget progress, account views, transaction lists, and related insights.

Must convey:

- App display is based on authorized product data.
- Data may be incomplete if institutions, permissions, imports, or services are unavailable.
- Avoid implying perfect categorization, perfect balances, or guaranteed insight accuracy.

### 6. Rex Context

Recommended copy:

> Rex may use approved Clarity context, such as spending summaries, budgets, goals, memory/context, and recent conversation history, to answer questions inside Clarity. Rex does not connect directly to banks outside Clarity's user-authorized account connection flow.

Must convey:

- Rex uses Clarity context.
- Rex is not the bank connector.
- Rex does not independently access financial institutions.
- AI responses should be reviewed by users.

### 7. Disconnection And Deletion

Recommended copy:

> You can disconnect connected accounts where supported and request deletion through the published Data Deletion path. Some retained records may remain where needed for legal, security, backup, or operational reasons, as explained in the Privacy Policy.

Must convey:

- Disconnection and deletion are different.
- Deletion process must match actual product/support behavior.
- Cross-link to `/data-deletion` and `/privacy`.

## Rex And Plaid Boundary

This exact boundary should appear somewhere in Security, Privacy, FAQ, or Terms:

> Plaid helps with user-authorized account connection. Clarity stores and organizes authorized product data. Rex may use Clarity context to assist the user, but Rex does not connect directly to financial institutions.

This helps avoid a common review confusion: users and reviewers should not think Rex itself is scraping banks or directly logging into accounts.

## What Not To Expose

Do not include:

- API keys, tokens, secrets, credentials, service account details, or env variable names.
- Database table names, schemas, row-level policy details, or internal data model names.
- Private hostnames, IP addresses, ports, service names, deployment paths, or VPS details.
- Internal logs, stack traces, raw provider payloads, or webhook payload examples.
- Exact network topology or admin tooling.
- Screenshots of production dashboards, backend consoles, Supabase logs, Plaid dashboard secrets, or systemd/service config.

Allowed:

- Plain-language provider categories.
- High-level product flow.
- Public route names such as `/privacy`, `/security`, `/data-deletion`, and `/contact`.
- General phrases like `hosted database`, `backend service`, `mobile app`, `AI provider`, and `speech provider`.

## Plaid-Friendly Wording

Use:

- `user-authorized connection`
- `supported financial accounts`
- `depending on permissions and institution support`
- `authorized account and transaction context`
- `Clarity context`
- `Rex may use approved Clarity context`
- `disconnect connected accounts`
- `request deletion`

Avoid:

- `Rex connects to your bank`
- `we access your bank whenever needed`
- `always connected`
- `real-time balances`
- `complete transaction history`
- `bank-grade flow`
- `Plaid-approved data pipeline`
- `direct bank access`

## Cross-Links

This section should link to:

- `/privacy` for detailed data categories, uses, vendors, retention, and rights.
- `/terms` for account-connection responsibilities and AI/financial advice boundaries.
- `/data-deletion` for deletion and disconnection instructions.
- `/contact` for support, privacy, or security questions.

## Visual Guidance

Preferred layout:

- Four to six step cards.
- A simple vertical flow on mobile.
- A horizontal timeline only if it remains readable on small screens.
- Short labels plus one sentence per step.

Avoid:

- Dense diagrams.
- Animated pipes/network graphics.
- Fake security dashboards.
- Any visual implying certification or bank partnership.

## Implementation Review Questions

Before publishing, verify:

- Does the account-connection explanation match the actual app flow?
- Does the data list match Privacy Policy data categories?
- Does the Rex context description match backend behavior?
- Does disconnection/deletion wording match actual support and product flows?
- Does the section avoid overclaiming real-time, complete, or always-available data?
- Does the section avoid exposing implementation internals?

## Acceptance Checklist

- Explains user consent, Plaid connection, backend storage, app display, and Rex context.
- Uses a simple diagram or bullet flow.
- Does not expose secrets, implementation internals, or private infrastructure.
- Distinguishes Plaid account connection from Rex AI assistance.
- Explains that data availability depends on permissions, institution support, and product configuration.
- Links to Privacy, Terms, Data Deletion, and Contact.
