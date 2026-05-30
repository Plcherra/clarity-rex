# Clarity Privacy Sharing And Vendors

Status: File 04 Phase 5 sharing and vendors section approved for initial landing launch draft.

Purpose: explain when Clarity shares or makes information available to service providers, legal/safety parties, or user-directed recipients without implying that Clarity sells personal financial data.

## Draft Section Title

Preferred:

- `How Clarity shares information`

Acceptable alternatives:

- `Service providers and limited sharing`
- `Vendors that help provide Clarity`

Avoid:

- `Who we sell data to`
- `Data brokers`
- `Partners that monetize your data`

## Plain-Language Intro

Recommended draft:

> Clarity uses service providers to operate the app, connect accounts, store data, power Rex, support voice features, respond to requests, secure the service, and maintain the public website. These providers process information to help provide Clarity.

Required boundary:

> Clarity does not sell personal financial data.

Recommended follow-up:

> Clarity does not share personal financial data for unrelated third-party advertising.

## Vendor Categories

Use category-based disclosure so the policy remains accurate if vendors change.

### Infrastructure, Hosting, And Backend Services

May include:

- Server hosting.
- Domain/DNS/CDN providers.
- Backend runtime and deployment infrastructure.
- Monitoring or readiness tooling.

Purpose:

- Operate the public website, backend API, voice/chat routes, and related services.

Known or likely examples to verify before launch:

- VPS/server hosting provider.
- Domain/DNS provider.

### Authentication, Database, And Storage

May include:

- User authentication.
- Database hosting.
- Row-level/user-scoped data storage.
- Backend data access used to provide Clarity.

Purpose:

- Sign users in, store profiles, accounts, transactions, budgets, conversations, memory/context, and related app data.

Known example:

- Supabase.

### Financial Account Connection

May include:

- Account connection provider.
- Institution metadata provider.
- Account and transaction data provider.

Purpose:

- Help users connect financial accounts with permission and provide authorized account/transaction context to Clarity.

Known example:

- Plaid.

Boundary:

- Do not imply Plaid sponsors, endorses, or approves Clarity unless that is formally true and reviewed.

### AI Assistant And Model Providers

May include:

- Large language model provider.
- AI routing or inference provider.
- Model observability metadata where enabled.

Purpose:

- Generate Rex responses, analyze user-authorized context, and support assistant features.

Known example:

- xAI/Grok.

Boundary:

- Do not imply AI providers are financial advisors or account connection providers.

### Speech-To-Text And Text-To-Speech Providers

May include:

- Speech-to-text provider.
- Text-to-speech provider.
- Voice processing infrastructure.

Purpose:

- Convert user-initiated voice interactions into text and generate spoken Rex responses.

Known examples:

- Deepgram for speech-to-text.
- Google Text-to-Speech for spoken responses.

Boundary:

- Do not claim audio or transcripts are never processed by vendors unless verified.
- Do not describe Rex as continuously listening.

### Contact, Waitlist, Support, And Email Providers

May include:

- Contact form provider.
- Email delivery provider.
- Support inbox or ticketing provider.
- Spam prevention or abuse-prevention provider.

Purpose:

- Receive and respond to support, privacy, security, deletion, waitlist, and beta access requests.

Known examples:

- To be confirmed before launch.

Boundary:

- Contact forms should not request bank credentials, account numbers, SSNs, or full card numbers.

### Analytics And Product Reliability Providers

May include:

- Website analytics.
- Product analytics.
- Crash/error reporting.
- Performance monitoring.

Purpose:

- Understand site/app reliability, fix broken flows, measure high-level usage, and improve product quality.

Known examples:

- To be confirmed before launch.

Boundary:

- If analytics are added, disclose them before launch.
- Do not imply unrelated third-party ad targeting.
- Do not call data anonymous unless truly anonymized.

### App Stores And Device Platforms

May include:

- Apple App Store or related platform services.
- Device operating-system services.

Purpose:

- Distribute the mobile app, manage platform-level app behavior, and support device permissions.

Boundary:

- Platform providers have their own privacy practices.

## Legal, Safety, And Compliance Sharing

Clarity may share or disclose information when needed to:

- Comply with applicable law, regulation, subpoena, or legal process.
- Respond to lawful requests from public authorities.
- Protect Clarity, users, or others from fraud, abuse, security threats, or harm.
- Enforce Terms of Service.
- Investigate security incidents.
- Complete vendor, platform, or Plaid-related compliance reviews.

Use careful language:

> We may disclose information if we believe it is reasonably necessary to comply with law, protect rights and safety, investigate abuse or security issues, enforce our terms, or complete required compliance reviews.

## User-Directed Sharing

Clarity may share information when the user asks or directs Clarity to do so, such as:

- Sending a support request.
- Requesting deletion or account help.
- Connecting an account through Plaid.
- Using Rex chat or voice features that require vendor processing.

This should be framed as user-directed product use, not hidden sharing.

## Business Transfers

Optional legal-review section:

> If Clarity is involved in a merger, acquisition, financing, reorganization, bankruptcy, or sale of assets, information may be transferred as part of that transaction, subject to this Privacy Policy or appropriate notice where required.

Include only after legal review.

## No-Sale And Advertising Boundary

Required:

- Clarity does not sell personal financial data.

Recommended:

- Clarity does not share personal financial data for unrelated third-party advertising.

Avoid:

- `We never share data`
- `No third parties ever process your data`
- `Vendors cannot process data`

Those claims conflict with real product providers.

## Vendor Review Checklist

Before publishing:

- Confirm final vendor list.
- Confirm whether analytics/contact form vendors are used.
- Confirm AI, speech, TTS, database, hosting, and account-connection providers.
- Confirm vendor names that should appear publicly.
- Confirm vendor privacy links where useful.
- Confirm no secrets, environment values, API keys, or internal URLs appear in public copy.
- Confirm sharing language matches Terms and Security pages.

## Acceptance Checklist

- Mentions infrastructure/hosting, auth/database, Plaid/account connection, AI, speech-to-text, text-to-speech, support/contact, and analytics if used.
- Says vendors process data to provide services.
- Discloses legal, safety, compliance, and user-directed sharing scenarios.
- States Clarity does not sell personal financial data.
- Avoids claiming no sharing or no vendor processing.
- Keeps vendor examples reviewable and updateable before launch.
