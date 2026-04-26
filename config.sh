#!/usr/bin/env bash
# OpenCodeSystem 共有設定
set -euo pipefail

SYSTEM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECTS_DIR="/home/kensan/Projects"
OPENCODE="opencode"

MODEL_PRO="deepseek/deepseek-v4-pro"
MODEL_FLASH="deepseek/deepseek-v4-flash"

MAX_RETRY=15
LOOP_HOURS=8
LOOP_SECONDS=$((LOOP_HOURS * 60 * 60))
SLEEP_BETWEEN_PHASES=3

PHASES=("monitor" "plan" "dev" "qa" "test" "fix" "pr" "done")

log() {
  local agent="$1" msg="$2"
  local logfile="$SYSTEM_ROOT/logs/${agent}.log"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $msg" >> "$logfile"
}

state_read() {
  cat "$SYSTEM_ROOT/state/state.json" 2>/dev/null || echo '{"phase":"monitor","retry":0,"task":"","status":"idle","project":""}'
}

state_write() {
  echo "$1" > "$SYSTEM_ROOT/state/state.json"
}

state_update() {
  local key="$1" val="$2"
  local s
  s=$(state_read)
  s=$(echo "$s" | jq --arg k "$key" --arg v "$val" '.[$k] = $v')
  state_write "$s"
}
