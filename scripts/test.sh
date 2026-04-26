#!/usr/bin/env bash
# Test: テスト実行
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/config.sh"

PROJECT_PATH="$1"
PROJECT_NAME=$(basename "$PROJECT_PATH")

log "test" "Starting test execution for $PROJECT_NAME"

PROMPT_FILE="$SCRIPT_DIR/agents/tester.md"
PROMPT=$(cat "$PROMPT_FILE")
PROMPT="${PROMPT//\{\{PROJECT_NAME\}\}/$PROJECT_NAME}"
PROMPT="${PROMPT//\{\{PROJECT_PATH\}\}/$PROJECT_PATH}"

cd "$PROJECT_PATH"
if $OPENCODE run --model "$MODEL_FLASH" --dangerously-skip-permissions "$PROMPT" 2>&1; then
  log "test" "Tests passed"
  exit 0
else
  log "test" "Tests failed"
  exit 1
fi
