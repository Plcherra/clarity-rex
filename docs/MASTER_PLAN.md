# MASTER_PLAN.md

**Canon:** product vision only. Behavioral rules live in [`CLARITY_RULES.md`](CLARITY_RULES.md). Code structure lives in [`PROJECT_STRUCTURE.md`](PROJECT_STRUCTURE.md).

## Project Goal

Clarity is one single app that combines personal finance with a companion assistant (Rex). Finance and the assistant must feel like one product, not two separate things. The assistant has access to the same accounts, transactions, budgets, goals, and people the user talks about.

**Clarity is the product. Rex is the assistant personality inside Clarity, not a separate app or system.**

## Core Promise

Everything important about your money and your goals lives in one calm place — and your assistant actually understands all of it.

Most finance apps show you numbers. Clarity lets you talk to them.

## Core Features

- Connect bank accounts using Plaid (CSV import as fallback)
- Dashboard, accounts, balances, and transaction history
- Budgets and goal tracking
- Knows — saved memory you control (People, Events, Preferences, Facts)
- Goals and Open Threads — objectives and opt-in companion follow-ups
- Chat and voice with the assistant
- Full dark theme across the entire app (light mode supported)

## Product Principles

- **One data truth** — Dashboard, Budgets, Transactions, Knows, Goals, and the assistant all read from the same sources.
- **Trust first** — never fake saved memory, completed actions, or financial numbers.
- **Confirm before change** — important, risky, or account-changing actions require user confirmation and backend success.
- **Calm design** — clean, readable, supportive; never shame the user.
- **Assistant is part of Clarity** — chat and voice are input modes, not a second product.

## Key Rules (summary)

- The assistant must follow real financial numbers, not guess.
- Full dark theme on every screen by default.
- The assistant only saves what the user explicitly confirms.
- Every durable action is backend-verified before success language is used.

This file is the product vision source of truth. All code and docs must align with it.
