# Clarity Plaid Consent Placement Contract

Status: Phase 6 Plaid consent placement approved for initial landing launch.

Purpose: make Clarity's account connection model clear before a user requests access, while using neutral language that does not imply Plaid sponsorship or endorsement.

## Required Placement

Plaid/data consent language must appear in three public places:

1. Home page trust bar.
2. Home page dedicated `Plaid & Data Consent` section.
3. FAQ questions about financial data, disconnection, and deletion.

These placements must appear before the final CTA on the home page.

## Home Trust Bar Copy Contract

The trust bar should include short claims only:

- User-authorized account connections.
- Account connection through Plaid.
- Transaction and balance data used for budgeting and insights.
- Disconnect and deletion paths available.

Copy constraints:

- Do not say "Plaid-approved" unless approval is formally granted and language is reviewed.
- Do not say "Plaid-backed", "Plaid-certified", or "partnered with Plaid".
- Do not claim Clarity can access accounts without user permission.

## Dedicated Consent Section Contract

The home page must include one dedicated section explaining account connection in plain language.

Working section title:

- `Connect accounts with your permission`

Required points:

- Clarity uses Plaid to let users connect financial accounts.
- Users choose when to connect an account.
- Depending on permissions and institution support, connected data may include account details, balances, transactions, and institution metadata.
- Clarity uses connected data to organize transactions, support budgets, generate spending insights, and give Rex relevant financial context.
- Users can disconnect accounts.
- Users can request deletion of their Clarity data.

Required links:

- Privacy Policy: `/privacy`
- Security: `/security`
- Data Deletion: `/data-deletion`
- Contact: `/contact` when mentioning support.

## Approved Draft Copy

This draft can be used as a starting point:

> Clarity uses Plaid so you can connect financial accounts with your permission. Depending on what your bank supports and what you authorize, Clarity may receive account details, balances, transactions, and institution information. Clarity uses this data to organize spending, support budgets, create insights, and give Rex relevant context. You can disconnect accounts and request deletion of your data at any time.

If final site copy changes, it must preserve the meaning above.

## FAQ Placement Contract

The public FAQ must include these questions:

### What financial data does Clarity access?

Required answer points:

- Only user-authorized connected account data.
- High-level examples: account information, balances, transactions, institution metadata.
- Actual data depends on institution support and permissions.

### How does Clarity connect to banks?

Required answer points:

- Clarity uses Plaid to help users connect accounts.
- Users authenticate through Plaid's connection flow.
- Clarity does not ask users to send bank passwords through contact forms or email.

### Can I disconnect or delete my data?

Required answer points:

- Users can disconnect accounts.
- Users can request deletion.
- Link `/data-deletion`.

### Is Clarity financial advice?

Required answer points:

- Clarity provides organization, insights, and AI assistance.
- Clarity is not a bank, broker, lender, tax advisor, or investment advisor.
- Users remain responsible for financial decisions.

## Forbidden Claims

Do not use these claims anywhere in v1 landing copy:

- "Plaid endorses Clarity."
- "Plaid-approved app" before formal approval and final copy review.
- "Bank-grade security" unless supported by a reviewed security claim.
- "We never store financial data" if Clarity stores transactions, categories, budgets, memories, or derived financial context.
- "Guaranteed savings" or guaranteed financial outcomes.
- "Rex manages your money for you."

## Consent UX Requirements

- Consent language must be visible on the home page before the final request-access CTA.
- The user should not have to open Privacy Policy to understand the basic data flow.
- Data use language must be short enough to read on mobile.
- Policy links must be close to the consent explanation.
- The request-access form must not ask for bank credentials, account numbers, or SSNs.

## Plaid Review Notes

Reviewers should be able to answer these questions from the public site:

- What does Clarity do?
- Why does Clarity need financial account data?
- What data may Clarity access?
- How does the user authorize access?
- How can the user disconnect or request deletion?
- How can the user contact support?

## Open Placeholders To Resolve Before Deployment

- Final reviewed home section copy.
- Final reviewed FAQ copy.
- Final support email or support form path.
- Final screenshots or demo media that show consent-adjacent product context without exposing personal data.
