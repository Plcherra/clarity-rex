"""Clarity Review Crew — a focused CrewAI team that reviews and fixes code.

Pipeline (sequential):
    1. ProjectReader  -> maps the codebase and explains how it is put together.
    2. BugFinder      -> hunts for real bugs, risks, and rule violations.
    3. FixSuggester   -> explains each problem in plain English + concrete fixes.
    4. FixApplier     -> applies the fix, runs tests, marks FIXED / FAILED / SKIPPED.

Modes:
    Normal    : one pass over a scoped folder; FixApplier is careful and skips
                risky fixes.
    Aggressive: scans the whole project (or a folder), applies every fix it can,
                retries or reverts on test failure, and loops pass-after-pass with
                no human intervention until no more edits happen or a max-fix cap
                is reached. Prioritizes speed and fixing over caution.

Run:
    python clarity_crew.py                              # normal, default scope
    python clarity_crew.py services/rex-api/app/services  # normal, one folder
    python clarity_crew.py --aggressive                 # aggressive, whole repo
    python clarity_crew.py services/rex-api --aggressive # aggressive, one folder

Enable aggressive mode with the --aggressive flag or AGGRESSIVE_FIX=true.
Configure via .env (see .env.example). Uses xAI Grok (cheap/fast) by default.
"""

from __future__ import annotations

import logging
import os
import sys
import traceback
from datetime import datetime
from pathlib import Path

from crewai import Agent, Crew, Process, Task
from dotenv import load_dotenv

from codebase_tools import (
    REPO_ROOT,
    edit_file,
    get_edit_count,
    list_directory,
    read_file,
    reset_edit_count,
    run_tests,
    search_code,
)
from grok_client import build_grok_llm

load_dotenv()
logging.basicConfig(level=logging.INFO, format="%(levelname)s %(name)s: %(message)s")
log = logging.getLogger("clarity_crew")

# --- Model: resilient xAI Grok (cheap + fast, retries empty responses) -------
# grok-3-mini is inexpensive and quick. Set XAI_API_KEY in .env. Tune the model,
# temperature, tokens, and retry behavior via env (see .env.example).
MODEL_NAME = os.environ.get("MODEL", "xai/grok-3-mini")

llm = build_grok_llm()

TOOLS = [list_directory, read_file, search_code]
# FixApplier also gets write + test tools so it can change code and verify it.
APPLIER_TOOLS = [list_directory, read_file, search_code, edit_file, run_tests]

# Aggressive-loop caps (override via env).
MAX_FIXES = int(os.environ.get("MAX_FIXES", "40"))
MAX_ROUNDS = int(os.environ.get("MAX_ROUNDS", "6"))


def build_agents(aggressive: bool) -> tuple[Agent, Agent, Agent, Agent]:
    project_reader = Agent(
        role="Project Reader",
        goal=(
            "Understand the Clarity codebase in the requested scope: its structure, "
            "the main modules, how they connect, and what each part is responsible for."
        ),
        backstory=(
            "You are a meticulous senior engineer who joins a project that is already "
            "80-90% built. You never guess — you use the tools to list directories, read "
            "files, and search code until you genuinely understand how things fit together. "
            "You care about the assistant pipeline (Grok brain + backend body), memory, "
            "voice, and finance wiring."
        ),
        tools=TOOLS,
        llm=llm,
        allow_delegation=False,
        verbose=True,
        max_iter=25,
    )

    bug_finder = Agent(
        role="Bug Finder",
        goal=(
            "Find real bugs, correctness risks, and rule violations in the code that the "
            "Project Reader mapped. Prioritize issues that would actually bite users."
        ),
        backstory=(
            "You are a sharp code auditor. You look for logic errors, None/null handling, "
            "race conditions, incorrect async usage, unhandled errors, security/scoping "
            "issues (user data must stay scoped), and violations of the project's rules "
            "(no fake memory, no invented balances, no silent saves, files under 500 lines). "
            "You read the actual code before claiming a bug and cite file + line numbers."
        ),
        tools=TOOLS,
        llm=llm,
        allow_delegation=False,
        verbose=True,
        max_iter=25,
    )

    fix_suggester = Agent(
        role="Fix Suggester",
        goal=(
            "Turn each confirmed issue into a plain-English explanation plus a concrete, "
            "minimal fix a developer can apply directly."
        ),
        backstory=(
            "You are a calm senior engineer who explains problems so a non-expert can "
            "follow. For every issue you state: what is wrong, why it matters, and exactly "
            "how to fix it (with a short code sketch when useful). You prefer root-cause "
            "fixes over patches and respect the existing architecture."
        ),
        tools=TOOLS,
        llm=llm,
        allow_delegation=False,
        verbose=True,
        max_iter=20,
    )

    if aggressive:
        applier_backstory = (
            "You are a fast, decisive engineer in AGGRESSIVE auto-fix mode. You apply "
            "every suggested fix immediately with edit_file, then run the relevant tests "
            "with run_tests. If tests fail, you try a DIFFERENT fix; if that also fails, "
            "you revert your change back to the original code and move on to the next "
            "issue — you never get stuck. You favor speed and fixing over caution, but you "
            "still never claim a fix works unless tests actually passed."
        )
        applier_max_iter = 60
    else:
        applier_backstory = (
            "You are a careful engineer who turns suggestions into real, working changes. "
            "You re-read the exact code before editing, apply the smallest change that "
            "solves the root cause with edit_file, then run the relevant tests with "
            "run_tests. You never claim success unless the tests actually pass. If a fix "
            "is risky, ambiguous, or would touch code you cannot verify, you leave it "
            "unapplied and explain why instead of guessing."
        )
        applier_max_iter = 30

    fix_applier = Agent(
        role="Fix Applier",
        goal=(
            "Apply the fixes suggested by the Fix Suggester directly to the code, run the "
            "relevant tests, and mark each issue FIXED / FAILED / SKIPPED."
        ),
        backstory=applier_backstory,
        tools=APPLIER_TOOLS,
        llm=llm,
        allow_delegation=False,
        verbose=True,
        max_iter=applier_max_iter,
    )

    return project_reader, bug_finder, fix_suggester, fix_applier


def build_tasks(
    scope: str,
    aggressive: bool,
    project_reader: Agent,
    bug_finder: Agent,
    fix_suggester: Agent,
    fix_applier: Agent,
) -> list[Task]:
    read_task = Task(
        description=(
            f"Explore the Clarity repository, focusing on this scope: '{scope}'.\n"
            "Use list_directory to see what exists, read_file to read the important files, "
            "and search_code to trace how pieces connect.\n"
            "Produce a clear map: the key files in scope, what each is responsible for, "
            "how data/control flows between them, and any areas that look fragile or "
            "overly complex. Note file sizes that look large (rule: keep under 500 lines)."
        ),
        expected_output=(
            "A structured overview of the scope: bullet list of key files with a one-line "
            "purpose each, a short description of how they interact, and a list of "
            "'areas worth a closer look' for the bug hunt."
        ),
        agent=project_reader,
    )

    bug_task = Task(
        description=(
            "Using the Project Reader's map, hunt for real bugs and issues in scope: "
            f"'{scope}'.\n"
            "Read the actual code before flagging anything. Look for: logic errors, "
            "None/empty handling, wrong async/await, unhandled exceptions, data-scoping/"
            "security problems, and violations of Clarity rules (no fake success/memory, "
            "no invented balances, no silent saves, files over 500 lines).\n"
            "Ignore purely stylistic nits — focus on things that could actually break or "
            "mislead users."
        ),
        expected_output=(
            "A numbered list of concrete issues. Each item: a short title, the file path "
            "and line number(s), severity (High/Medium/Low), and 1-3 sentences describing "
            "the problem and the evidence you saw in the code."
        ),
        agent=bug_finder,
        context=[read_task],
    )

    fix_task = Task(
        description=(
            "Take the Bug Finder's numbered issues and, for each one, write a plain-English "
            "explanation and a concrete fix.\n"
            "Re-read the relevant code if needed to make the fix accurate. Prefer minimal, "
            "root-cause fixes that respect the existing architecture. Do NOT rewrite whole "
            "files; give focused changes."
        ),
        expected_output=(
            "A final Markdown report titled '# Clarity Review Report'. For each issue: \n"
            "- **Issue** (title, file:line, severity)\n"
            "- **In plain English** (what's wrong and why it matters)\n"
            "- **Suggested fix** (clear steps, with a short code sketch when helpful)\n"
            "End with a short 'Top 3 things to fix first' summary."
        ),
        agent=fix_suggester,
        context=[read_task, bug_task],
        output_file="clarity_review_report.md",
    )

    if aggressive:
        apply_description = (
            "AGGRESSIVE AUTO-FIX. Take the Fix Suggester's report and apply EVERY fix you "
            f"can to the actual code in scope: '{scope}'. Work through all issues without "
            "asking for permission.\n"
            "For each issue:\n"
            "1. Re-read the relevant file to confirm the exact current code.\n"
            "2. Apply the fix immediately with edit_file (focused change, no whole-file "
            "rewrites).\n"
            "3. Run the relevant tests with run_tests (closest test file/folder, e.g. "
            "services/rex-api/tests).\n"
            "4. If tests pass, mark FIXED. If they FAIL, try a DIFFERENT fix; if that also "
            "fails, revert your edit back to the original code and mark REVERTED, then move "
            "on. Do not get stuck on any single issue.\n"
            "Keep going until you have attempted every issue. Prioritize speed and fixing."
        )
    else:
        apply_description = (
            "Take the Fix Suggester's report and apply the fixes to the actual code in "
            f"scope: '{scope}'.\n"
            "For each issue, in order:\n"
            "1. Re-read the relevant file to confirm the exact current code.\n"
            "2. Apply the minimal fix with edit_file (smallest change that solves the "
            "root cause; do not rewrite whole files).\n"
            "3. Run the relevant tests with run_tests (target the closest test file/folder, "
            "e.g. services/rex-api/tests).\n"
            "4. If the tests pass, mark the issue FIXED. If they fail, report the failure "
            "output and, if you cannot safely resolve it, revert your change back to the "
            "original code so the repo stays green.\n"
            "If an issue is too ambiguous or risky to apply safely, leave it UNAPPLIED and "
            "explain why. Never claim a fix works unless tests actually passed."
        )

    apply_task = Task(
        description=apply_description,
        expected_output=(
            "A Markdown section titled '# Fix Application Results'. For each issue: the "
            "title, the file(s) changed, status (FIXED / FAILED / REVERTED / SKIPPED), the "
            "test command target and its pass/fail result, and a one-line note. End with a "
            "summary count of fixed vs. failed vs. reverted vs. skipped."
        ),
        agent=fix_applier,
        context=[fix_task],
        output_file="clarity_fix_results.md",
    )

    return [read_task, bug_task, fix_task, apply_task]


def _build_crew(scope: str, aggressive: bool) -> Crew:
    reader, finder, suggester, applier = build_agents(aggressive)
    tasks = build_tasks(scope, aggressive, reader, finder, suggester, applier)
    return Crew(
        agents=[reader, finder, suggester, applier],
        tasks=tasks,
        process=Process.sequential,
        verbose=True,
    )


def _parse_args(argv: list[str]) -> tuple[str | None, bool]:
    """Return (scope, aggressive). scope is None if not provided."""
    aggressive = os.environ.get("AGGRESSIVE_FIX", "").lower() in {"1", "true", "yes"}
    scope: str | None = None
    for arg in argv:
        if arg in {"--aggressive", "-a"}:
            aggressive = True
        elif not arg.startswith("-") and scope is None:
            scope = arg
    return scope, aggressive


def _write_error_report(scope: str, aggressive: bool, exc: Exception) -> None:
    """Record a run failure to the fix-results file so it isn't just a traceback."""
    fixes_path = Path("clarity_fix_results.md").resolve()
    stamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    detail = "".join(traceback.format_exception_only(type(exc), exc)).strip()
    note = (
        f"\n\n---\n\n## Run error ({stamp})\n\n"
        f"- **Scope:** `{scope}`  |  **Mode:** {'aggressive' if aggressive else 'normal'}\n"
        f"- **Edits applied before failure:** {get_edit_count()}\n"
        f"- **Error:** {detail}\n\n"
        "The crew stopped this pass because the Grok model could not return a "
        "usable response (empty output or repeated API errors) even after retries. "
        "Things to try: lower `MAX_TOKENS` pressure by narrowing the scope, switch "
        "to a non-reasoning model (`MODEL=xai/grok-3`), or re-run — earlier applied "
        "edits are preserved.\n"
    )
    try:
        with fixes_path.open("a", encoding="utf-8") as handle:
            handle.write(note)
    except Exception:  # noqa: BLE001 - never mask the original error
        pass


def _run_once(scope: str, aggressive: bool):
    crew = _build_crew(scope, aggressive)
    return crew.kickoff()


def main() -> None:
    scope_arg, aggressive = _parse_args(sys.argv[1:])
    # Aggressive mode defaults to the whole repo; normal mode to the backend services.
    default_scope = "." if aggressive else "services/rex-api/app/services"
    scope = scope_arg or default_scope

    print(f"Repo root : {REPO_ROOT}")
    print(f"Scope     : {scope}")
    print(f"Model     : {MODEL_NAME}")
    print(f"Mode      : {'AGGRESSIVE auto-fix' if aggressive else 'normal (single pass)'}")
    if aggressive:
        print(f"Limits    : max {MAX_FIXES} fixes, max {MAX_ROUNDS} rounds")
    print()

    reset_edit_count()
    last_result = None

    if not aggressive:
        try:
            last_result = _run_once(scope, aggressive)
        except Exception as exc:  # noqa: BLE001 - report instead of crashing
            log.error("Crew run failed: %s", exc)
            _write_error_report(scope, aggressive, exc)
            last_result = f"Run failed: {exc}"
    else:
        round_num = 0
        while round_num < MAX_ROUNDS and get_edit_count() < MAX_FIXES:
            round_num += 1
            edits_before = get_edit_count()
            print(f"\n{'#' * 70}\n# Aggressive round {round_num} "
                  f"(edits so far: {edits_before})\n{'#' * 70}")
            try:
                last_result = _run_once(scope, aggressive)
            except Exception as exc:  # noqa: BLE001 - keep prior edits, stop cleanly
                log.error("Aggressive round %d failed: %s", round_num, exc)
                _write_error_report(scope, aggressive, exc)
                last_result = f"Round {round_num} failed: {exc}"
                print("Stopping aggressive loop after error; earlier edits are kept.")
                break
            edits_this_round = get_edit_count() - edits_before
            print(f"\n[round {round_num}] edits applied this round: {edits_this_round} "
                  f"(total: {get_edit_count()})")
            if edits_this_round == 0:
                print("No edits applied this round — no more fixable issues. Stopping.")
                break
        else:
            if get_edit_count() >= MAX_FIXES:
                print(f"\nReached max fixes ({MAX_FIXES}). Stopping.")
            else:
                print(f"\nReached max rounds ({MAX_ROUNDS}). Stopping.")

    report_path = Path("clarity_review_report.md").resolve()
    fixes_path = Path("clarity_fix_results.md").resolve()
    print("\n" + "=" * 70)
    print("Clarity Review Crew finished.")
    print(f"Total edits applied: {get_edit_count()}")
    if report_path.exists():
        print(f"Review report saved to: {report_path}")
    if fixes_path.exists():
        print(f"Fix results saved to:   {fixes_path}")
    print("=" * 70)
    print(last_result)


if __name__ == "__main__":
    main()
