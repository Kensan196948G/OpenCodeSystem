#!/usr/bin/env bash
# Git: ブランチ作成・コミット・プッシュ
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/config.sh"

if [ -z "${TARGET_PROJECT:-}" ]; then
  echo "[git_prepare] Error: TARGET_PROJECT が設定されていません"
  exit 1
fi

PROJECT_PATH="$PROJECTS_DIR/$TARGET_PROJECT"

cd "$PROJECT_PATH"

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" = "main" ] || [ "$CURRENT_BRANCH" = "master" ]; then
  echo "[git_prepare] Error: main/master ブランチで直接作業できません"
  exit 1
fi

BRANCH="ai/opencode-$(date +%Y%m%d-%H%M%S)"
git checkout -b "$BRANCH"

git add .

if git diff --cached --quiet; then
  echo "[git_prepare] 変更なし。commitをスキップします。"
  exit 0
fi

git commit -m "auto: OpenCodeSystem update"
git push -u origin "$BRANCH"

echo "$BRANCH" > "$SYSTEM_ROOT/state/current_branch.txt"
echo "[git_prepare] Branch: $BRANCH pushed"

exit 0
