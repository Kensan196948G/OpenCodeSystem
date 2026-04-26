#!/usr/bin/env bash
# Dev: 実装
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/config.sh"

PROJECT_PATH="$1"
PROJECT_NAME=$(basename "$PROJECT_PATH")

log "dev" "Starting dev for $PROJECT_NAME"

TASK=$(state_read | jq -r '.task // "implement features"')

PROMPT_FILE="$SCRIPT_DIR/agents/dev.md"
PROMPT=$(cat "$PROMPT_FILE")
PROMPT="${PROMPT//\{\{PROJECT_NAME\}\}/$PROJECT_NAME}"
PROMPT="${PROMPT//\{\{PROJECT_PATH\}\}/$PROJECT_PATH}"
PROMPT="${PROMPT//\{\{TASK_DESCRIPTION\}\}/$TASK}"
PROMPT="${PROMPT//\{\{TASK_FILES\}\}/$(state_read | jq -r '.task_files // "[]"')}"

cd "$PROJECT_PATH"
if $OPENCODE run --model "$MODEL_FLASH" --dangerously-skip-permissions "$PROMPT" 2>&1; then
  log "dev" "Implementation completed"
  exit 0
else
  log "dev" "Implementation failed"
  exit 1
fi
