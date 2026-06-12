# CLARITY_RULES.md

## 1. Project Overview

Clarity is a personal AI assistant that combines personal finance tracking with life guidance and accountability.

It connects to your bank accounts, tracks your spending, helps you stay on budget, remembers important things about your life and goals, and gives you honest, contextual advice through both chat and voice.

The core promise of Clarity is simple: Everything important about your money and your goals lives in one place, and your AI assistant (Rex) actually understands all of it.

Clarity is the product. Rex is the assistant personality inside Clarity, not a separate app.

## 2. Core Philosophy & Product Values

- Build for trust first.
- Keep the app clear, calm, and useful every day.
- Prefer simple, maintainable code over clever abstractions.
- Never fake success. If something was not saved, synced, deleted, or updated, do not claim it was.
- The UI and Rex must always operate from the same data truth.
- Keep financial data private and user-scoped.
- Use deterministic rules for obvious financial logic. Use AI only where it truly adds value.
- Plaid is the primary source of financial data. CSV/manual import is a fallback.

## 3. Tech Stack

- Mobile: Flutter / Dart
- Backend: Python / FastAPI (`services/rex-api`)
- Database & Auth: Supabase / Postgres
- Bank Connections: Plaid
- Assistant: Backend-owned LLM services
- Voice: Mobile capture + backend voice session services

## 4. Folder Structure

Use feature-first organization:

```text
feature/
  domain/          # models, policies, business rules
  application/     # workflows, controllers, use cases
  data/            # repositories, API clients, mappers
  presentation/    # screens, widgets, view models
```

## 5. Coding Standards & Conventions

- Keep files focused (target 150-300 lines).
- Split files before they grow beyond 500 lines.
- Use clear, specific domain names. Avoid vague names like `utils`, `helper`, `manager`.
- Keep business logic out of UI widgets.
- Add tests for important logic and workflows.
- Do not silently swallow user-critical errors.

## 6. Architecture Principles

- Presentation depends on application/domain, never the reverse.
- Plaid tokens must remain backend-owned.
- Financial read models are the single source of truth for Dashboard, Budgets, Transactions, and Rex.
- Durable actions (saving, updating, deleting) must be confirmed by the backend before Rex or UI claims success.
- All user data must be properly scoped to the authenticated user.

## 7. Key Features Rules

**Rex / Voice (Most Important)**

- Rex must feel like part of Clarity, not a separate app.
- Rex must always use the same data the user sees in the app.
- Rex must never claim it performed a durable action unless the backend confirms success.
- Rex must say when data is missing, stale, or degraded.
- Rex must ask for confirmation before making important changes.
- Rex must distinguish clearly between insights, suggestions, and completed actions.
- Rex should be honest, calm, and supportive - never shame the user.

**Plaid, Transactions, Accounts, Budgets**

- Backend owns all Plaid logic and token management.
- Persist Plaid data before using it in dashboards, budgets, or Rex.
- All features must use the same normalized transaction and account models.
- Budgets must reflect the same truth shown in the dashboard and used by Rex.

## 8. Common Mistakes to Avoid

- Treating Rex as a separate app
- Letting Rex and the UI use different data
- Claiming success before backend confirmation
- Putting Plaid logic in the wrong place
- Creating god files or giant components
- Hiding errors from the user
- Using vague file/function names

## 9. How to Use This File

When working on any task, always keep these rules in mind. Start important conversations by referencing relevant sections from this file.
