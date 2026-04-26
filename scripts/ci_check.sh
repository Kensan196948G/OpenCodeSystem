#!/usr/bin/env bash
# CI: PRのCI状態確認
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/config.sh"

if [ -z "${TARGET_PROJECT:-}" ]; then
  echo "[ci_check] Error: TARGET_PROJECT が設定されていません"
  exit 1
fi

PROJECT_PATH="$PROJECTS_DIR/$TARGET_PROJECT"

cd "$PROJECT_PATH"

PR_URL_FILE="$SYSTEM_ROOT/state/current_pr_url.txt"
if [ ! -f "$PR_URL_FILE" ]; then
  echo "[ci_check] Error: current_pr_url.txt が見つかりません"
  exit 1
fi

PR_URL=$(cat "$PR_URL_FILE")

gh pr checks "$PR_URL" --json name,state,bucket,link > "$SYSTEM_ROOT/state/ci_checks.json" 2>/dev/null

FAILED=$(jq '[.[] | select(.bucket=="fail")] | length' "$SYSTEM_ROOT/state/ci_checks.json" 2>/dev/null || echo 0)
PENDING=$(jq '[.[] | select(.bucket=="pending")] | length' "$SYSTEM_ROOT/state/ci_checks.json" 2>/dev/null || echo 0)

if [ "$FAILED" -gt 0 ]; then
  echo "[ci_check] fail"
  exit 1
fi

if [ "$PENDING" -gt 0 ]; then
  echo "[ci_check] pending"
  exit 8
fi

echo "[ci_check] pass"
exit 0
