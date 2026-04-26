#!/usr/bin/env bash
# QA: テスト生成
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/config.sh"

PROJECT_PATH="$1"
PROJECT_NAME=$(basename "$PROJECT_PATH")

log "qa" "Starting QA for $PROJECT_NAME"

PROMPT_FILE="$SCRIPT_DIR/agents/qa.md"
PROMPT=$(cat "$PROMPT_FILE")
PROMPT="${PROMPT//\{\{PROJECT_NAME\}\}/$PROJECT_NAME}"
PROMPT="${PROMPT//\{\{PROJECT_PATH\}\}/$PROJECT_PATH}"
PROMPT="${PROMPT//\{\{FILES_MODIFIED\}\}/$(state_read | jq -r '.files_modified // "[]"')}"

cd "$PROJECT_PATH"
if $OPENCODE run --model "$MODEL_FLASH" --dangerously-skip-permissions "$PROMPT" 2>&1; then
  log "qa" "Test generation completed"
  exit 0
else
  log "qa" "Test generation failed"
  exit 1
fi
