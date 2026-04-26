#!/usr/bin/env bash
# CI修復ループ: 最大15回リトライ
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/config.sh"

if [ -z "${TARGET_PROJECT:-}" ]; then
  echo "[ci_repair] Error: TARGET_PROJECT が設定されていません"
  exit 1
fi

PROJECT_PATH="$PROJECTS_DIR/$TARGET_PROJECT"
MAX_RETRY=15
RETRY=0

cd "$PROJECT_PATH"

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" = "main" ] || [ "$CURRENT_BRANCH" = "master" ]; then
  echo "[ci_repair] Error: main/master ブランチで直接作業できません"
  exit 1
fi

while [ "$RETRY" -lt "$MAX_RETRY" ]; do
  echo "[ci_repair] CI確認: $((RETRY + 1)) / $MAX_RETRY"

  if bash "$SCRIPT_DIR/scripts/ci_check.sh"; then
    echo "[ci_repair] CI成功"
    exit 0
  fi
  RESULT=$?

  if [ "$RESULT" -eq 8 ]; then
    echo "[ci_repair] CI実行中。60秒待機"
    sleep 60
    continue
  fi

  echo "[ci_repair] CI失敗。DeepSeekで修復します。"

  PROMPT_FILE="$SCRIPT_DIR/agents/ci_repair.md"
  PROMPT=$(cat "$PROMPT_FILE")
  PROMPT="${PROMPT//\{\{PROJECT_NAME\}\}/$TARGET_PROJECT}"
  PROMPT="${PROMPT//\{\{PROJECT_PATH\}\}/$PROJECT_PATH}"

  if $OPENCODE run --model "$MODEL_FLASH" --dangerously-skip-permissions "$PROMPT" >> "$SYSTEM_ROOT/logs/ci_repair.log" 2>&1; then
    git add .
    if ! git diff --cached --quiet; then
      git commit -m "fix: repair CI failure (attempt $((RETRY + 1)))"
      git push
    fi
  fi

  RETRY=$((RETRY + 1))
done

echo "[ci_repair] CI修復上限に到達しました。人間レビューが必要です。"
exit 1
