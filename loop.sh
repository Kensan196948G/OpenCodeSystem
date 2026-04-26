#!/usr/bin/env bash
# 8時間制御ループ
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

if [ -z "${TARGET_PROJECT:-}" ]; then
  TARGET_PROJECT=$(jq -r '.project' "$SYSTEM_ROOT/state/state.json" 2>/dev/null)
  if [ -z "$TARGET_PROJECT" ] || [ "$TARGET_PROJECT" = "null" ]; then
    echo "[LOOP] Error: プロジェクトが指定されていません"
    exit 1
  fi
fi

PROJECT_PATH="$PROJECTS_DIR/$TARGET_PROJECT"
START=$(date +%s)
LIMIT=$LOOP_SECONDS
CYCLE=0

echo "[LOOP] 開始: $(date)"
echo "[LOOP] 制限時間: ${LOOP_HOURS}時間 (${LIMIT}秒)"
echo "[LOOP] プロジェクト: $TARGET_PROJECT"

while true; do
  NOW=$(date +%s)
  ELAPSED=$((NOW - START))

  if [ "$ELAPSED" -ge "$LIMIT" ]; then
    echo "[LOOP] 制限時間到達 (${ELAPSED}s)。終了します。"
    state_update "status" "timeout"
    break
  fi

  CYCLE=$((CYCLE + 1))
  REMAINING=$((LIMIT - ELAPSED))
  echo "[LOOP] サイクル #${CYCLE} | 経過: ${ELAPSED}s | 残り: ${REMAINING}s"

  state_update "status" "running"
  export TARGET_PROJECT

  if bash "$SCRIPT_DIR/orchestrator.sh"; then
    echo "[LOOP] Orchestrator 成功"
  else
    echo "[LOOP] Orchestrator 異常終了"
  fi

  CURRENT_PHASE=$(jq -r '.phase' "$SYSTEM_ROOT/state/state.json")
  if [ "$CURRENT_PHASE" = "done" ]; then
    echo "[LOOP] 全フェーズ完了。終了します。"
    break
  fi

  sleep "$SLEEP_BETWEEN_PHASES"
done

echo "[LOOP] 終了: $(date)"
echo "[LOOP] 合計サイクル: ${CYCLE}"
