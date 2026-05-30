# Clarity Public FAQ Contract

Status: Phase 7 public FAQ structure approved for initial landing launch.

Purpose: answer predictable product, trust, data, and support questions in plain language without turning the home page into a legal document.

## FAQ Placement

The FAQ must appear on the home page after the Plaid/data consent section and product proof section, and before the final CTA.

The FAQ may also be reused or expanded later on a dedicated support page, but v1 does not require a separate FAQ route.

## FAQ Tone Rules

All FAQ answers must:

- Use plain language.
- Stay short enough to scan on mobile.
- Link to detailed pages for policy specifics.
- Avoid legalese where a simple answer works.
- Avoid product promises that are not implemented.

All FAQ answers must not:

- Present Clarity as a bank, broker, lender, tax advisor, or investment advisor.
- Suggest Plaid endorses or sponsors Clarity.
- Promise guaranteed savings, budgeting outcomes, or financial improvement.
- Ask users to send bank passwords, account numbers, SSNs, or private credentials.

## Required FAQ Questions

### 1. What is Clarity?

Required answer points:

- Clarity is a personal AI financial co-pilot.
- Clarity helps users organize transactions, budgets, spending context, and financial decisions.
- Clarity is currently focused on private beta/request access.

Recommended short answer:

> Clarity is a personal AI financial co-pilot that helps you organize transactions, budgets, spending context, and decisions in one place.

### 2. Who is Rex?

Required answer points:

- Rex is the AI assistant inside Clarity.
- Rex can help explain spending, budgets, goals, and remembered context.
- Rex is not the product name.

Recommended short answer:

> Rex is the AI assistant inside Clarity. Rex helps you ask questions about your money, budgets, goals, and saved context.

### 3. What financial data does Clarity access?

Required answer points:

- Only user-authorized connected account data.
- Examples may include account information, balances, transactions, and institution metadata.
- Actual data depends on permissions, account type, and institution support.
- Link Privacy.

Recommended short answer:

> When you choose to connect an account, Clarity may receive account information, balances, transactions, and institution details depending on your permissions and institution support. Read the Privacy Policy for more detail.

### 4. How does account connection work?

Required answer points:

- Clarity uses Plaid to help users connect financial accounts.
- Users authorize account access through Plaid's connection flow.
- Clarity does not ask users to email or type bank passwords into public forms.
- Link Security.

Recommended short answer:

> Clarity uses Plaid to help you connect accounts with your permission. You authorize access through Plaid's connection flow; Clarity does not ask you to email or submit bank passwords.

### 5. How does Clarity use connected data?

Required answer points:

- Budgeting.
- Transaction organization/categorization.
- Spending insights.
- Rex financial context.
- Clarity does not sell personal financial data in v1.

Recommended short answer:

> Clarity uses connected data to organize transactions, support budgets, create spending insights, and give Rex relevant financial context.

### 6. Can I disconnect accounts or delete my data?

Required answer points:

- Users can disconnect accounts.
- Users can request deletion of Clarity data.
- Link Data Deletion.
- Link Contact if support is needed.

Recommended short answer:

> Yes. You can disconnect accounts and request deletion of your Clarity data. Start with the Data Deletion page or contact support for help.

### 7. Is Clarity financial advice?

Required answer points:

- Clarity provides organization, insights, and AI assistance.
- Clarity is not financial, investment, tax, or legal advice.
- Users remain responsible for decisions.
- Important decisions should involve qualified professionals.

Recommended short answer:

> No. Clarity provides organization, insights, and AI assistance, but it is not financial, investment, tax, or legal advice. You remain responsible for your decisions.

### 8. How do I contact support?

Required answer points:

- Link Contact.
- Include support email once finalized.
- Tell users not to send bank credentials or sensitive account details through public forms.

Recommended short answer:

> Use the Contact page to reach support. Please do not send bank passwords, account numbers, or sensitive credentials through public forms or email.

## Optional FAQ Questions For V1

These may be added if the home page has room:

- Is Clarity available now?
- What platforms does Clarity support?
- Can I use Clarity without connecting a bank account?
- How is Rex different from a normal chatbot?

Optional questions must not push required trust/data questions below the final CTA on mobile.

## Link Requirements

FAQ answers should link to:

- `/privacy` for data collection, use, retention, and privacy rights.
- `/security` for data handling and security posture.
- `/data-deletion` for deletion requests.
- `/contact` for support and privacy/security questions.
- `/terms` for service boundaries and user obligations when relevant.

## Implementation Notes

- Use accordion behavior only if answers remain reachable and keyboard accessible.
- If using accordions, default-open the most trust-critical question on desktop or ensure the section summary makes the data model visible.
- On mobile, avoid overly tall expanded panels that hide the final CTA entirely.
- Keep FAQ content in a data file or structured component so copy can be reviewed without hunting through layout code.

## Open Placeholders To Resolve Before Deployment

- Final support email.
- Final privacy/security contact path.
- Final wording after legal review.
- Decision on accordion vs always-visible layout.
