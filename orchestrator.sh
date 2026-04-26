#!/usr/bin/env bash
# Orchestrator: フェーズ状態遷移管理
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

PHASE=$(jq -r '.phase' "$SYSTEM_ROOT/state/state.json")
RETRY=$(jq -r '.retry' "$SYSTEM_ROOT/state/state.json")
PROJECT_PATH="$PROJECTS_DIR/$TARGET_PROJECT"

# モデル使い分け: Pro=管理/計画, Flash=実行/テスト/修正
case "$PHASE" in
  monitor|plan)
    export OPENCODE_MODEL="$MODEL_PRO"
    ;;
  dev|qa|test|fix|github|pr)
    export OPENCODE_MODEL="$MODEL_FLASH"
    ;;
  *)
    export OPENCODE_MODEL="$MODEL_FLASH"
    ;;
esac

echo "[ORCH] Phase: $PHASE | Retry: $RETRY | Model: $OPENCODE_MODEL | Project: $TARGET_PROJECT"

case "$PHASE" in
  monitor)
    log "orchestrator" "Phase: monitor"
    if bash "$SCRIPT_DIR/scripts/monitor.sh" "$PROJECT_PATH"; then
      state_update "phase" "plan"
      state_update "retry" "0"
    else
      state_update "status" "error"
    fi
    ;;

  plan)
    log "orchestrator" "Phase: plan"
    if bash "$SCRIPT_DIR/scripts/plan.sh" "$PROJECT_PATH"; then
      state_update "phase" "dev"
      state_update "retry" "0"
    else
      state_update "status" "error"
    fi
    ;;

  dev)
    log "orchestrator" "Phase: dev"
    if bash "$SCRIPT_DIR/scripts/dev.sh" "$PROJECT_PATH"; then
      state_update "phase" "qa"
      state_update "retry" "0"
    else
      state_update "status" "error"
    fi
    ;;

  qa)
    log "orchestrator" "Phase: qa"
    if bash "$SCRIPT_DIR/scripts/qa.sh" "$PROJECT_PATH"; then
      state_update "phase" "test"
      state_update "retry" "0"
    else
      state_update "status" "error"
    fi
    ;;

  test)
    log "orchestrator" "Phase: test"
    if bash "$SCRIPT_DIR/scripts/test.sh" "$PROJECT_PATH"; then
      state_update "phase" "github"
      state_update "retry" "0"
    else
      state_update "phase" "fix"
      state_update "retry" "0"
    fi
    ;;

  fix)
    log "orchestrator" "Phase: fix (retry=${RETRY}/${MAX_RETRY})"
    if [ "$RETRY" -ge "$MAX_RETRY" ]; then
      log "orchestrator" "MAX RETRY exceeded"
      state_update "status" "aborted"
      exit 1
    fi
    if bash "$SCRIPT_DIR/scripts/fix.sh" "$PROJECT_PATH"; then
      state_update "phase" "dev"
      state_update "retry" "0"
    else
      RETRY=$((RETRY + 1))
      state_update "retry" "$RETRY"
    fi
    ;;

  github)
    log "orchestrator" "Phase: github"
    if bash "$SCRIPT_DIR/scripts/git_prepare.sh"; then
      if bash "$SCRIPT_DIR/scripts/github_pr.sh"; then
        if bash "$SCRIPT_DIR/scripts/ci_repair_loop.sh"; then
          state_update "phase" "done"
          state_update "status" "completed"
        else
          state_update "status" "ci_failed"
        fi
      fi
    fi
    ;;

  pr)
    log "orchestrator" "Phase: pr"
    if bash "$SCRIPT_DIR/scripts/pr.sh" "$PROJECT_PATH"; then
      state_update "phase" "done"
      state_update "status" "completed"
    fi
    ;;

  done)
    log "orchestrator" "Phase: done - 全工程完了"
    state_update "status" "completed"
    ;;

  *)
    log "orchestrator" "Unknown phase: $PHASE"
    state_update "status" "error"
    exit 1
    ;;
esac

sleep "$SLEEP_BETWEEN_PHASES"
