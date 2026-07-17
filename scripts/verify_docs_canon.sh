#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

BASE_REF="${DOCS_CANON_BASE_REF:-origin/main}"
if ! git rev-parse --verify "$BASE_REF" >/dev/null 2>&1; then
  BASE_REF="HEAD~1"
fi

ALLOWED_ROOT=(
  "docs/MASTER_PLAN.md"
  "docs/CLARITY_RULES.md"
  "docs/PROJECT_STRUCTURE.md"
)

is_allowed_docs_path() {
  local path="$1"
  local allowed
  for allowed in "${ALLOWED_ROOT[@]}"; do
    if [[ "$path" == "$allowed" ]]; then
      return 0
    fi
  done
  return 1
}

mapfile -t ADDED < <(git diff --name-only --diff-filter=A "$BASE_REF"...HEAD -- docs/ || true)

if [[ ${#ADDED[@]} -eq 0 ]]; then
  echo "Docs canon check passed (no new files under docs/)."
  exit 0
fi

violations=()
for path in "${ADDED[@]}"; do
  if ! is_allowed_docs_path "$path"; then
    violations+=("$path")
  fi
done

if [[ ${#violations[@]} -eq 0 ]]; then
  echo "Docs canon check passed (${#ADDED[@]} new docs file(s) allowed)."
  exit 0
fi

echo "Docs canon check failed. New files under docs/ must be canon only:" >&2
echo "  Allowed: docs/MASTER_PLAN.md, docs/CLARITY_RULES.md, docs/PROJECT_STRUCTURE.md" >&2
echo "  (docs/archive/** is not allowed — delete competing material; do not archive under docs/)" >&2
for path in "${violations[@]}"; do
  echo "  - $path" >&2
done
exit 1
