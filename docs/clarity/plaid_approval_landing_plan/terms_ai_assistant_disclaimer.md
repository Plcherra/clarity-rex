# Clarity Terms AI Assistant Disclaimer

Status: File 05 Phase 4 AI assistant disclaimer approved for initial landing launch draft.

## Purpose

This contract defines the Terms of Service language for Rex, the AI assistant inside Clarity. It should explain that Rex can be useful while setting realistic expectations about accuracy, review, and user responsibility.

The section should feel normal and professional, not alarming. The goal is: Rex helps, users review important outputs.

## Draft Section Titles

Preferred:

- `Rex and AI-assisted responses`

Acceptable alternatives:

- `Using Rex`
- `AI assistant expectations`
- `Reviewing assistant responses`

Avoid:

- `AI risk waiver`
- `Hallucination disclaimer`
- `Rex liability`
- `Automated decision making`

## Product Positioning

Recommended draft:

> Rex is the AI assistant inside Clarity. Rex can help explain spending, budgets, goals, conversations, and product context using information available in Clarity.

This should be paired with the review language below.

## Accuracy And Review Boundary

Recommended draft:

> AI-assisted responses may be incomplete, outdated, misunderstood, or inaccurate. You should review important outputs before relying on them, especially when they affect money, taxes, credit, legal matters, health, work, relationships, or major commitments.

This language should stay broad enough for Rex's personal co-pilot behavior while still matching the financial boundary.

## User Responsibility

Recommended draft:

> You are responsible for the decisions you make and the actions you take based on Clarity or Rex. Rex can help you think through information, but Rex does not make decisions for you.

This reinforces user agency without making Rex feel useless.

## No Autonomous Financial Actions

Recommended draft:

> Rex does not execute transactions, move money, open accounts, apply for credit, make purchases, file taxes, enter contracts, or take other external actions on your behalf unless a future feature clearly asks for and receives your separate confirmation.

Launch note:

- If future action-taking features are added, this section must be reviewed before launch.
- Any future action flow must require explicit user confirmation and clear UI.

## Context And Memory Limitations

Recommended draft:

> Rex may use conversation history, approved memory, goals, budgets, and authorized financial context where available. Rex may not always have complete, current, or correct context, and connected account data can depend on provider availability, institution support, imports, sync timing, and user permissions.

This keeps expectations realistic for Plaid-connected data, imported CSVs, memory, and voice/chat context.

## Voice And Transcription Limitations

Recommended draft:

> Voice features may rely on speech-to-text and text-to-speech processing. Transcripts, partial transcripts, or spoken responses may be imperfect, especially with background noise, accents, device routing, connection issues, or provider availability.

Do not overdo this in the public Terms, but the concept should be present enough to avoid promising perfect voice behavior.

## Model And Vendor Processing

Recommended draft:

> To provide Rex, Clarity may send relevant prompts, conversation content, voice-derived text, product context, and related metadata to AI or voice service providers as described in the Privacy Policy.

This should cross-link to `/privacy` and `/security`.

## Wording Rules

Use:

- `AI-assisted responses`
- `may be incomplete or inaccurate`
- `review important outputs`
- `Rex helps you think through information`
- `Rex does not make decisions for you`
- `explicit confirmation`
- `authorized financial context`

Avoid:

- `Rex is always right`
- `Rex knows everything`
- `guaranteed accurate`
- `automatic decisions`
- `Rex manages your money`
- `Rex pays bills`
- `Rex invests`
- `Rex files taxes`
- `Rex replaces professional advice`

## Cross-Page Alignment

The AI assistant disclaimer must align with:

- `terms_financial_advice_boundary.md`
- `rex_assistant_feature_section.md`
- `privacy_data_categories.md`
- `privacy_purpose_of_processing.md`
- `privacy_sharing_and_vendors.md`
- `privacy_retention_and_deletion.md`
- `public_faq_contract.md`
- `hero_core_positioning.md`

If Rex copy changes in the landing page, review this Terms section and the FAQ together.

## Acceptance Checklist

- States AI responses may be incomplete, outdated, misunderstood, or inaccurate.
- Tells users to review important outputs before relying on them.
- Makes clear users remain responsible for decisions and actions.
- States Rex does not execute transactions, move money, open accounts, apply for credit, make purchases, file taxes, enter contracts, or take external actions for users.
- Explains Rex context and connected data may be incomplete or delayed.
- Mentions voice/transcription limitations without making voice sound unreliable.
- Cross-links conceptually to Privacy and Security for AI/voice provider processing.

