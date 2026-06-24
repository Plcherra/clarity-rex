# Project Structure - Clarity

## Main Technologies

- Flutter + Dart (Mobile App)
- Python + FastAPI (Backend - Rex API)
- Supabase (Database & Auth)
- Plaid (Bank connections)

## Folder Structure

`apps/mobile/lib` - All Flutter/Dart code

- `apps/mobile/lib/app` - App bootstrap, composition root, routing shell glue
- `apps/mobile/lib/core` - Supabase/Rex config, shared models, formatting, IO
- `apps/mobile/lib/features` - Main app features (dashboard, accounts, budgets, transactions, profile)
- `apps/mobile/lib/rex` - Everything related to Rex assistant (chat, voice, memory, goals)
- `apps/mobile/lib/theme` - Shared Clarity design tokens and Material themes
- `apps/mobile/lib/widgets` - Reusable UI components

`services/rex-api` - Python backend

- All FastAPI endpoints, Plaid sync logic, memory handling

## Important

All financial features must live under `/lib/features`.

All Rex-related code must live under `/lib/rex`.

They must share the same data models from `/lib/core`.

This structure must be kept clean. No mixing of Rex code inside features, and no mixing of financial code inside Rex.
