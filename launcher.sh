#!/usr/bin/env bash
# OpenCodeSystem エントリポイント
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export OPENCODE_SYSTEM="$SCRIPT_DIR"

echo "=========================================="
echo "  OpenCodeSystem (ClaudeOS v8互換)"
echo "  自律開発基盤"
echo "=========================================="

echo "起動中..."

# Cron起動時は TARGET_PROJECT が既に設定されている
if [ -z "${TARGET_PROJECT:-}" ]; then
  bash "$SCRIPT_DIR/selector.sh"
else
  echo "プロジェクト: $TARGET_PROJECT (環境変数)"
  echo "{ \"project\": \"$TARGET_PROJECT\", \"phase\": \"monitor\", \"retry\": 0, \"task\": \"\", \"status\": \"running\" }" > "$SCRIPT_DIR/state/state.json"
fi

bash "$SCRIPT_DIR/loop.sh"
