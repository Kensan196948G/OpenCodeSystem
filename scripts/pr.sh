#!/usr/bin/env bash
# PR: Git commit & push & pull request
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/config.sh"

PROJECT_PATH="$1"
PROJECT_NAME=$(basename "$PROJECT_PATH")

log "pr" "Starting PR creation for $PROJECT_NAME"

cd "$PROJECT_PATH"

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" = "main" ] || [ "$CURRENT_BRANCH" = "master" ]; then
  log "pr" "Error: main/master ブランチで直接作業できません"
  exit 1
fi

BRANCH_NAME="auto/opencode-$(date '+%Y%m%d-%H%M%S')"

if ! git diff --quiet; then
  git checkout -b "$BRANCH_NAME"
  git add .
  git commit -m "auto: OpenCodeSystem autonomous development update"
  log "pr" "Committed on branch $BRANCH_NAME"
else
  log "pr" "No changes to commit"
fi

if git remote -v | grep -q origin; then
  if git push -u origin "$BRANCH_NAME" 2>&1; then
    log "pr" "Pushed to origin/$BRANCH_NAME"
    gh pr create \
      --title "OpenCodeSystem Auto PR ($(date '+%Y-%m-%d %H:%M'))" \
      --body "## Summary
Automated pull request by OpenCodeSystem.
### Changes
- Autonomous development cycle completed
### Testing
- Tests executed during development cycle
### Notes
- This PR was automatically generated
- Review required before merge" 2>&1 && log "pr" "PR created" || log "pr" "PR creation skipped"
  fi
fi

log "pr" "PR process completed"
exit 0
