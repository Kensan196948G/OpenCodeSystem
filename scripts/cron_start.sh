#!/usr/bin/env bash
# Cron起動: OpenCodeSystem をバックグラウンドで開始
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

OPENCODE_SYSTEM="$SCRIPT_DIR"
export OPENCODE_SYSTEM

PID_FILE="$OPENCODE_SYSTEM/state/pid.txt"
LOG_DIR="$OPENCODE_SYSTEM/logs"
START_LOG="$LOG_DIR/start.log"
CRON_LOG="$LOG_DIR/cron.log"

mkdir -p "$LOG_DIR"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$START_LOG"
}

log "=== Cron起動開始 ==="

# 多重起動防止
if [ -f "$PID_FILE" ]; then
  OLD_PID=$(cat "$PID_FILE")
  if [ -n "$OLD_PID" ] && ps -p "$OLD_PID" > /dev/null 2>&1; then
    log "多重起動検出: PID $OLD_PID は実行中。起動をスキップします。"
    exit 1
  else
    log "古いPID $OLD_PID は実行中ではありません。クリアして続行。"
    rm -f "$PID_FILE"
  fi
fi

# プロジェクト選択（set -e 対策で || ガード）
PROJECT=$(bash "$OPENCODE_SYSTEM/scripts/project_selector.sh") || {
  log "Error: プロジェクト選択に失敗しました"
  exit 1
}

export TARGET_PROJECT="$PROJECT"
log "選択プロジェクト: $TARGET_PROJECT"

# 起動前の状態初期化
echo "{ \"project\": \"$TARGET_PROJECT\", \"phase\": \"monitor\", \"retry\": 0, \"task\": \"\", \"status\": \"running\" }" > "$OPENCODE_SYSTEM/state/state.json"

# バックグラウンド実行
log "launcher.sh を起動します (プロジェクト: $TARGET_PROJECT)"
nohup bash "$OPENCODE_SYSTEM/launcher.sh" >> "$CRON_LOG" 2>&1 &
LAUNCHER_PID=$!

echo "$LAUNCHER_PID" > "$PID_FILE"
log "起動完了: PID $LAUNCHER_PID"

exit 0
