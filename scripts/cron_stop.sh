#!/usr/bin/env bash
# Cron停止: OpenCodeSystem を systemd 経由で強制停止
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

OPENCODE_SYSTEM="$SCRIPT_DIR"
export OPENCODE_SYSTEM

PID_FILE="$OPENCODE_SYSTEM/state/pid.txt"
STOP_LOG="$OPENCODE_SYSTEM/logs/stop.log"

mkdir -p "$OPENCODE_SYSTEM/logs"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$STOP_LOG"
}

log "=== Cron停止開始 ==="

UNIT="opencode-run"

# 状態更新
echo "$(cat "$OPENCODE_SYSTEM/state/state.json" 2>/dev/null || echo '{}')" | \
  jq --arg v "stopped" '.status = $v' > "$OPENCODE_SYSTEM/state/state.json" 2>/dev/null || true

# 方法1: systemd による停止（優先）
if systemctl --user is-active "$UNIT" > /dev/null 2>&1; then
  log "systemd unit $UNIT を停止します"
  systemctl --user stop "$UNIT" 2>/dev/null || true
  sleep 3

  if ! systemctl --user is-active "$UNIT" > /dev/null 2>&1; then
    log "systemd 停止完了: $UNIT"
    rm -f "$PID_FILE"
    exit 0
  else
    log "systemd 停止失敗。kill にフォールバックします。"
  fi
fi

# 方法2: PID ファイルによる kill（フォールバック）
if [ ! -f "$PID_FILE" ]; then
  log "PIDファイルが見つかりません。実行中プロセスはありません。"
  exit 0
fi

PID=$(cat "$PID_FILE")

if [ -z "$PID" ]; then
  log "PIDが空です。"
  rm -f "$PID_FILE"
  exit 0
fi

if ! ps -p "$PID" > /dev/null 2>&1; then
  log "PID $PID は既に終了しています。"
  rm -f "$PID_FILE"
  exit 0
fi

# 2段階停止: SIGTERM → SIGKILL
log "停止シグナル送信: kill $PID"
kill "$PID" 2>/dev/null || true

sleep 5

if ps -p "$PID" > /dev/null 2>&1; then
  log "正常停止失敗。強制停止: kill -9 $PID"
  kill -9 "$PID" 2>/dev/null || true
  sleep 1

  if ps -p "$PID" > /dev/null 2>&1; then
    log "Error: PID $PID を強制停止できませんでした"
    exit 1
  fi
fi

rm -f "$PID_FILE"
log "停止完了: PID $PID"

exit 0
