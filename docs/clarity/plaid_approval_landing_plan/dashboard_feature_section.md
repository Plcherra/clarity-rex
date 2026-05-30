# Clarity Dashboard Feature Section

Status: File 03 Phase 3 dashboard feature section approved for initial landing launch.

Purpose: present Clarity's financial overview clearly without confusing account balance, monthly cash flow, spending, or budget progress.

## Section Role

The dashboard section should show that Clarity helps users review financial activity in one place.

It should focus on:

- Monthly income.
- Monthly spending.
- Cash flow: income minus spending.
- Spending pressure.
- Budget performance.
- Transaction exploration by month, category, row, account, and role.

It should not focus on:

- Raw account balance as the primary promise.
- Forecasting exact future cash.
- Predicting runway.
- Investment performance.
- Credit decisions.

## Recommended Section Title

Preferred:

- `See cash flow, spending pressure, and budget progress together`

Acceptable alternatives:

- `A clearer financial overview`
- `Understand what changed this month`
- `Review income, spending, budgets, and transactions in one place`

Avoid:

- `Know your exact balance instantly`
- `Predict your financial future`
- `Fix spending automatically`
- `Never miss a financial problem`

## Recommended Section Copy

Preferred short copy:

> Clarity organizes monthly income, spending, budget progress, and transaction details so you can quickly review what changed and where your money is going.

Optional supporting copy:

> Use the dashboard to move from high-level cash flow into months, categories, rows, and account-specific details.

## Feature Bullets

Recommended bullets:

- Compare income and spending for the selected month.
- Spot spending pressure by category.
- Review budget progress against user-set targets.
- Inspect transactions by month, category, row, account, or role.

## Balance And Cash Flow Language

Use:

- `Cash flow`
- `Income`
- `Spending`
- `Monthly net`
- `Statement balance` only when the UI explicitly shows statement balance and the source is clear.

Avoid:

- Treating `balance` and `cash flow` as the same thing.
- Calling monthly net an account balance.
- Promising real-time bank balance if the product is using imported statements or delayed connected data.
- Presenting `$0` balance as a product value in screenshots unless intentionally explained.

## Screenshot Guidance

Approved screenshot concepts:

- Dashboard cash-flow card with synthetic income/spending.
- Spending pressure section with synthetic categories.
- Budget performance section with synthetic budget rows.
- Transaction months/categories/rows view with synthetic merchants and amounts.

Do not show:

- Real account names unless staged.
- Real bank logos.
- Real transaction merchants.
- Real balances.
- Import progress/toast/debug states.
- Old UI where balance/cash-flow language is confusing.

## Plaid Review Alignment

This section should help reviewers understand why Clarity needs account and transaction data:

- Transactions power categorization and spending review.
- Account/statement information helps contextualize cash flow where available.
- Budget progress depends on user transaction data.
- The user controls connected account access.

## Copy Boundaries

Do not claim:

- Clarity forecasts exact future balances.
- Clarity guarantees savings.
- Clarity gives financial advice.
- Clarity replaces professional advice.
- Clarity has real-time data if the implementation depends on institution/data-provider timing.

## Acceptance Checklist

- Explains income, spending, budget progress, and transaction insight.
- Avoids promising exact financial forecasting.
- Avoids confusing balance with monthly cash flow.
- Uses clean screenshot or product mock with synthetic/staged data.
- Links conceptually to account/transaction data use without overclaiming.
