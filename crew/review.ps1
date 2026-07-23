# REVIEW a path (no edits) — the cheap default. Writes clarity_review_report.md.
#
# Usage:
#   .\review.ps1                                  # whole repo
#   .\review.ps1 services/rex-api/app/services    # one folder
$env:PYTHONUTF8 = "1"
$env:PYTHONIOENCODING = "utf-8"
& "$PSScriptRoot\.venv\Scripts\python.exe" "$PSScriptRoot\clarity_crew.py" @args
