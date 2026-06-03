# Codex System Instructions

Last updated: June 3, 2026

## Purpose

This document summarizes the project-local expectations Codex should follow when working in the Clarity + Rex repository. It complements `docs/UNIVERSAL_CODE_ARCHITECTURE_STANDARDS.md` and exists so project-wide audits have a stable root-level instructions file to read.

## Operating Principles

- Prefer implementation over proposals when the user's request is actionable.
- Read the existing code before changing behavior.
- Keep changes focused on the requested task and surrounding ownership boundary.
- Preserve user or teammate changes. Do not revert unrelated dirty work.
- Use `rg` / `rg --files` for search.
- Use focused tests that match the risk of the change.
- Keep manual phone testing as the final release gate after automated cleanup is complete.

## Architecture Standards

- Follow `docs/UNIVERSAL_CODE_ARCHITECTURE_STANDARDS.md`.
- Keep production files under 500 lines whenever practical.
- Generated files may exceed the line limit if documented as exceptions.
- Prefer focused services, widgets, and helpers over growing orchestration files.
- Keep public facades stable unless a contract update is explicitly part of the phase.

## Rex Reliability Rules

- Rex must not claim a durable action happened unless backend execution confirms it.
- Memory states must be explicit:
  - saved memory means Rex can recall it;
  - pending review means Rex does not know it yet;
  - correction means a saved fact may need a deliberate update.
- Chat answers about memory review must use the same source of truth as the Memory tab.
- Voice failures must not be silent and must not corrupt text chat state.

## Release Rules

- Automated checks must pass before manual device testing:
  - backend tests;
  - Flutter analyze;
  - Flutter tests;
  - web build;
  - file-size scan;
  - Supabase migration/RLS verification.
- Manual device testing is intentionally last.
- The release checklist lives at `docs/clarity/release_checklists/FULL_PROJECT_RELEASE_GATE.md`.

## Documentation Rules

- New modules should include a module contract when they introduce a durable boundary.
- Architecture decisions that affect future work should use an ADR.
- Master plans should record:
  - phase status;
  - files changed;
  - line-count ledger;
  - verification commands;
  - known risks and manual checks deferred.
