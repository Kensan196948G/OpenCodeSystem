#!/usr/bin/env bash
# Plan: Managerタスク分解
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/config.sh"

PROJECT_PATH="$1"
PROJECT_NAME=$(basename "$PROJECT_PATH")

log "plan" "Starting plan for $PROJECT_NAME"

REQUIREMENTS=$(state_read | jq -r '.requirements // "No specific requirements"')

PROMPT_FILE="$SCRIPT_DIR/agents/manager.md"
PROMPT=$(cat "$PROMPT_FILE")
PROMPT="${PROMPT//\{\{PROJECT_NAME\}\}/$PROJECT_NAME}"
PROMPT="${PROMPT//\{\{PROJECT_PATH\}\}/$PROJECT_PATH}"
PROMPT="${PROMPT//\{\{REQUIREMENTS\}\}/$REQUIREMENTS}"

cd "$PROJECT_PATH"
if $OPENCODE run --model "$MODEL_PRO" --dangerously-skip-permissions "$PROMPT" 2>&1; then
  log "plan" "Task decomposition completed"
  exit 0
else
  log "plan" "Task decomposition failed"
  exit 1
fi
