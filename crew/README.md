# Clarity Review Crew

A focused **4-agent CrewAI team** that reads the Clarity codebase, finds bugs,
explains fixes in plain English, and can apply them. It works in **sequence**:

1. **ProjectReader** — maps the code in scope: key files, responsibilities, how they connect.
2. **BugFinder** — hunts for real bugs, risks, and Clarity-rule violations (cites file:line).
3. **FixSuggester** — explains each problem plainly and gives a concrete, minimal fix.
4. **FixApplier** — applies the minimal fix directly, runs the relevant tests, and marks
   each issue FIXED / FAILED / SKIPPED (reverting or leaving unapplied when tests fail).

The first three agents only get **read-only** tools (`list_directory`, `read_file`,
`search_code`), all sandboxed to the repo root. **FixApplier** additionally gets
`edit_file` (single, exact, unique-match replacement) and `run_tests` (pytest) so it can
change code and verify it — still sandboxed to the repo root.

> Note: FixApplier writes to your source files. Run on a clean branch/commit so you can
> review or revert its changes with git. The review report is written before any edits.

## Aggressive auto-fix mode

Enable with the `--aggressive` flag or `AGGRESSIVE_FIX=true` in `.env`. In this mode the
crew runs **fully automatically, no human intervention**:

- Scans the **whole repo** by default (or the folder you pass).
- FixApplier applies **every** fix it can, immediately.
- If tests fail, it tries a **different fix**; if that also fails it **reverts** and moves on.
- It **loops pass-after-pass** until a pass makes no more edits, or it hits the caps
  `MAX_FIXES` (default 40) / `MAX_ROUNDS` (default 6).
- Prioritizes speed and fixing over caution.

```powershell
python clarity_crew.py --aggressive                     # whole repo
python clarity_crew.py services/rex-api --aggressive    # one folder, aggressive
```

> ⚠️ Aggressive mode edits many files automatically and favors fixing over safety.
> **Always run it on a clean git branch** so you can review the full diff and revert.
> Tune the caps with `MAX_FIXES` and `MAX_ROUNDS` (see `.env.example`).

## Setup

```powershell
cd crew
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
copy .env.example .env       # then edit .env and add your API key
```

By default it uses the cheap/fast **xAI Grok** model `xai/grok-3-mini`. Add your
`XAI_API_KEY` (from https://console.x.ai) to `.env`. To use a bigger Grok model,
change `MODEL` in `.env` (e.g. `xai/grok-3` or `xai/grok-4`).

## Run

```powershell
# Review a sensible default scope (services/rex-api/app/services)
python clarity_crew.py

# Review a specific folder or file (path relative to repo root)
python clarity_crew.py services/rex-api/app/services/capabilities
python clarity_crew.py apps/mobile/lib/rex/chat
```

The review is saved to `crew/clarity_review_report.md`, and FixApplier's results
(what was fixed vs. failed vs. skipped, with test output) are saved to
`crew/clarity_fix_results.md`.

## Reliability (empty-response handling)

Grok reasoning models (`grok-3-mini`) sometimes return an empty completion —
CrewAI then raises `Invalid response from LLM call - None or empty`. The crew is
hardened against this via `grok_client.py`:

- **Retries up to 3 times** when Grok returns None/empty or the API errors out,
  with a short backoff **and escalating temperature** (0.1 → 0.5 → 0.9). The mini
  model is a reasoning model that occasionally emits only hidden reasoning with
  empty visible content; a plain retry at low temperature reproduces the same
  empty, so bumping temperature lets it take a different path.
- **Non-reasoning fallback**: if it still comes back empty, that single call is
  handed to `FALLBACK_MODEL` (default `xai/grok-3`), which reliably returns
  visible content. Set `FALLBACK_MODEL=none` to disable.
- **Lower `TEMPERATURE` (0.1)** for steadier output, **`MAX_TOKENS` cap (4000)**,
  and **`REASONING_EFFORT=low`** to reduce rate-limit pressure and wasted reasoning.
- If a run *still* fails after retries and fallback, the crew **doesn't crash with
  a raw traceback** — it logs a clear message and appends a "Run error" note to
  `clarity_fix_results.md`, keeping any edits already applied.

Want maximum reliability from the start? Set `MODEL=xai/grok-3` (non-reasoning) in `.env`.

## Notes

- Scope keeps token usage (and cost) low — point it at one area at a time rather
  than the whole repo.
- Nothing is modified: the crew only reads and reports. Apply the suggested fixes
  yourself after reviewing them.
