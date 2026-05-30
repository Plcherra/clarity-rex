# Clarity Privacy Feature Section

Status: File 03 Phase 6 privacy feature section approved for initial landing launch.

Purpose: make privacy and data handling visible on the landing page, with plain-language trust cards that link to full Privacy, Security, Terms, and Data Deletion pages.

## Section Role

The privacy feature section should show that Clarity treats financial data access as an explicit, user-authorized product choice.

It should focus on:

- User consent before account connection.
- Plain-language data use.
- Practical security posture.
- AI and voice transparency.
- Account disconnection and deletion support.
- Clear contact path.

It should not focus on:

- Unsupported security certifications.
- Absolute privacy guarantees.
- Technical internals that expose implementation details.
- Legal language that belongs only in policy pages.

## Recommended Section Title

Preferred:

- `Built around consent and clear data handling`

Acceptable alternatives:

- `Privacy is part of the product`
- `You choose what Clarity can use`
- `Clear controls for financial context`

Avoid:

- `Bank-level security`
- `Your data is 100% private`
- `We never process your data`
- `Unlimited protection`

## Recommended Section Copy

Preferred short copy:

> Clarity uses account and transaction context only after user authorization, explains what the data supports, and provides clear paths to disconnect accounts or request deletion.

Optional supporting copy:

> Rex can use approved Clarity context to answer more useful questions, while privacy, security, and deletion details remain easy to find.

## Recommended Trust Cards

Use four to six compact cards.

### Consent First

Copy:

> Connect accounts only when you choose to. Clarity explains why account and transaction context is used before asking for access.

Link:

- `/security` or `/privacy`

### Clear Data Use

Copy:

> Transaction and account context powers spending review, budgets, categorization, and Rex conversations inside Clarity.

Link:

- `/privacy`

### Practical Safeguards

Copy:

> Clarity uses secure transport, hosted infrastructure protections, and limited access practices to support the app.

Link:

- `/security`

### AI And Voice Transparency

Copy:

> Rex chat and voice features may process conversation or audio-derived content to provide responses.

Link:

- `/privacy`

### Disconnect Or Delete

Copy:

> Users can disconnect financial accounts and request deletion through published support paths.

Link:

- `/data-deletion`

### Support Contact

Copy:

> Questions about privacy, data, or security can be sent to the published Clarity support contact.

Link:

- `/contact`

## Required Cross-Links

The privacy feature section should link to:

- Privacy Policy.
- Terms of Service.
- Security and Data Handling.
- Data Deletion.
- Contact or support.

These links may point to placeholders during planning, but must resolve before launch.

## Plaid-Friendly Language

Use:

- `user-authorized account connection`
- `account and transaction context`
- `disconnect accounts`
- `request deletion`
- `Privacy Policy`
- `Security and Data Handling`

Avoid:

- `we access your bank whenever we want`
- `Rex watches your money`
- `always listening`
- `guaranteed secure`
- `bank-grade`
- `anonymous` unless data is truly anonymized.

## Claims That Require Verification

Do not publish these without implementation/legal verification:

- Specific encryption-at-rest details.
- SOC 2, ISO, PCI, or similar certification claims.
- Exact deletion timeframes.
- Exact support response times.
- Zero-retention AI or speech processing claims.
- Claims that vendors never retain or use data.

## Screenshot And Visual Guidance

The privacy section should generally use cards/icons, not product screenshots.

Allowed visuals:

- Simple consent/control card icons.
- Data flow illustration at a high level.
- Privacy/security checklist layout.

Avoid:

- Screenshots of Plaid Link.
- Screenshots of real account connection.
- Screenshots showing real emails, account names, tokens, logs, or raw provider data.
- Padlock-heavy visuals that imply unsupported security guarantees.

## Acceptance Checklist

- Cards cover consent, data use, security posture, AI/voice transparency, deletion, and support.
- Links point toward full policy/security/deletion pages.
- Uses plain language.
- Avoids vague or unsupported trust claims.
- Helps Plaid reviewers see account access is user-authorized and purpose-bound.
