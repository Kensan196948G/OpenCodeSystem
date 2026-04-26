#!/usr/bin/env bash
# GitHub: PR作成
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/config.sh"

if [ -z "${TARGET_PROJECT:-}" ]; then
  echo "[github_pr] Error: TARGET_PROJECT が設定されていません"
  exit 1
fi

PROJECT_PATH="$PROJECTS_DIR/$TARGET_PROJECT"

cd "$PROJECT_PATH"

BRANCH_FILE="$SYSTEM_ROOT/state/current_branch.txt"
if [ ! -f "$BRANCH_FILE" ]; then
  echo "[github_pr] Error: current_branch.txt が見つかりません"
  exit 1
fi

BRANCH=$(cat "$BRANCH_FILE")

PR_URL=$(gh pr create \
  --base main \
  --head "$BRANCH" \
  --title "auto: OpenCodeSystem update" \
  --body "OpenCodeSystem / DeepSeek V4 による自動更新PRです。CI結果を確認してください。")

echo "$PR_URL" | tee "$SYSTEM_ROOT/state/current_pr_url.txt"
echo "[github_pr] PR created: $PR_URL"

exit 0
