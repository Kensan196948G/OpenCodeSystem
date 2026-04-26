#!/usr/bin/env bash
# Fix: CIManager修復
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/config.sh"

PROJECT_PATH="$1"
PROJECT_NAME=$(basename "$PROJECT_PATH")

log "fix" "Starting fix cycle for $PROJECT_NAME"

PROMPT_FILE="$SCRIPT_DIR/agents/cimanager.md"
PROMPT=$(cat "$PROMPT_FILE")
PROMPT="${PROMPT//\{\{PROJECT_NAME\}\}/$PROJECT_NAME}"
PROMPT="${PROMPT//\{\{PROJECT_PATH\}\}/$PROJECT_PATH}"
PROMPT="${PROMPT//\{\{TEST_ERRORS\}\}/$(state_read | jq -r '.test_errors // "Unknown"')}"

cd "$PROJECT_PATH"
if $OPENCODE run --model "$MODEL_FLASH" --dangerously-skip-permissions "$PROMPT" 2>&1; then
  log "fix" "Fix completed"
  exit 0
else
  log "fix" "Fix failed"
  exit 1
fi
