# Clarity Privacy Data Categories

Status: File 04 Phase 2 privacy data categories approved for initial landing launch draft.

Purpose: define the categories of information Clarity may collect or process so the public Privacy Policy is complete, plain-language, and aligned with the app, Rex, account connection, support, and future Plaid review.

## Draft Section Title

Recommended:

- `Information Clarity may collect`

Acceptable alternatives:

- `Information we handle`
- `Data used to provide Clarity`

Avoid:

- `Everything we collect`
- `Bank data only`
- `Anonymous data`

## Plain-Language Intro

Recommended draft:

> The information Clarity handles depends on how you use the product, what you choose to connect, and which permissions are available from your financial institution or data provider.

Optional follow-up:

> You should not send bank passwords, account numbers, card numbers, or other sensitive financial credentials through public contact forms or support email.

## Account And Profile Information

May include:

- Name or display name.
- Email address.
- Authentication account identifier.
- Profile settings.
- App preferences.
- Onboarding state.
- Account creation and update timestamps.

Purpose summary:

- Used to create accounts, authenticate users, personalize the app, provide support, and maintain product settings.

## Financial Account Information

May include, depending on user authorization, institution support, and product configuration:

- Financial institution name or metadata.
- Account name or display label.
- Account type, such as checking or credit.
- Account identifiers or provider identifiers.
- Account connection status.
- Available, current, or statement balance where supported.
- Imported statement metadata.

Purpose summary:

- Used to organize account context, support dashboard views, connect transactions to accounts, and help Rex answer questions using authorized Clarity context.

## Transaction And Categorization Information

May include:

- Transaction date.
- Merchant or transaction description.
- Amount.
- Transaction type or financial role.
- Account association.
- Category.
- Budget/category matching information.
- Imported CSV or statement metadata.
- Duplicate-detection or import status metadata.
- User corrections to categories or roles.

Purpose summary:

- Used for transaction organization, categorization, spending review, budget progress, dashboard summaries, and Rex context.

## Budget, Goal, And Planning Information

May include:

- Budget names or categories.
- Budget amounts.
- Budget period, such as monthly, weekly, or custom.
- Spent and remaining budget calculations.
- Goals, plans, milestones, commitments, and related progress.
- User-entered planning details.

Purpose summary:

- Used to help users compare spending against their own targets and keep plans connected to Clarity and Rex.

## Rex Chat And Conversation Information

May include:

- Chat messages sent to Rex.
- Rex responses.
- Conversation titles or history.
- Attachments or structured action confirmations if supported.
- Memory correction or candidate information generated from conversations.
- Financial context included with a Rex request.
- Model routing or observability metadata when enabled.

Purpose summary:

- Used to provide Rex conversations, maintain conversation history, improve context, support memory review, and troubleshoot the assistant experience.

## Voice And Audio-Derived Information

May include:

- Audio captured during a voice interaction.
- Transcripts or partial transcripts.
- Voice turn metadata, such as duration, status, or timestamps.
- Generated Rex responses.
- Audio playback or text-to-speech response metadata.
- Error or diagnostic information needed to operate voice features.

Purpose summary:

- Used to provide voice interactions with Rex, convert speech to text, generate assistant responses, and improve voice reliability.

Important boundary:

> Clarity should not describe Rex as continuously listening. Voice data should be described as tied to user-initiated voice interactions.

## Memory And Personal Context

May include:

- User-approved long-term memory.
- Pending memory candidates.
- Memory corrections.
- Entities, preferences, events, personal rules, plans, milestones, and commitments.
- Source conversation references.
- Importance, status, or review metadata.

Purpose summary:

- Used to make Rex more context-aware, allow users to review or correct remembered context, and keep assistant responses more relevant over time.

## Device, App, And Log Information

May include:

- Device type and operating system information.
- App version.
- Network or request metadata.
- Authentication/session metadata.
- Backend request logs.
- Error logs.
- Performance or readiness diagnostics.
- Feature/debug metadata where enabled.

Purpose summary:

- Used to operate, secure, debug, and improve Clarity.

Boundary:

- Do not claim Clarity collects exact location unless a location feature is actually implemented and reviewed.

## Website, Waitlist, Contact, And Support Information

May include:

- Name.
- Email address.
- Contact message content.
- Waitlist or beta access request details.
- Support request details.
- Privacy, security, or deletion request details.
- Basic website analytics if implemented later.

Purpose summary:

- Used to respond to requests, manage access, process deletion/support requests, and operate the public site.

## Derived And Generated Information

May include:

- Spending summaries.
- Budget progress calculations.
- Category suggestions.
- Merchant or transaction rules.
- Rex-generated explanations.
- Memory candidates.
- Risk or review flags used to keep memory and assistant behavior safe.

Purpose summary:

- Used to make Clarity features useful while still depending on the underlying user-authorized data and user-controlled product flows.

## Sensitive Data Boundaries

The Privacy Policy should state:

- Clarity may process sensitive financial context when users connect or import financial data.
- Users should not submit bank login credentials through Clarity contact forms or support messages.
- Public site forms should not request bank credentials, full account numbers, card numbers, Social Security numbers, or similar sensitive identifiers.
- If a user sends sensitive details through support, Clarity may need to handle them to respond, but users should avoid doing so.

## Plaid-Friendly Wording

Use:

- `may include, depending on permissions and institution support`
- `user-authorized account connection`
- `account and transaction information`
- `financial context`
- `voice interaction`
- `chat messages and assistant responses`

Avoid:

- `we collect all bank data`
- `we always have real-time balances`
- `we never store financial data`
- `anonymous data` unless truly anonymized
- `bank credentials`
- `always listening`

## Acceptance Checklist

- Covers account/profile information.
- Covers financial account data, transactions, and balances where available.
- Covers budgets, goals, plans, and memory/context.
- Covers chat and voice content explicitly.
- Covers device/log data.
- Covers waitlist/contact/support messages.
- Explains financial data comes from user-authorized connections or user-provided imports.
- Uses `may include` language where data depends on permissions, institution support, or feature use.
- Avoids hidden categories and unsupported collection claims.
