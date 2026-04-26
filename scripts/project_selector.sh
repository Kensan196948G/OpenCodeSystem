#!/usr/bin/env bash
# プロジェクト自動選択
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config/project.conf"
PROJECTS_DIR="/home/kensan/Projects"

if [ -f "$CONFIG_FILE" ]; then
  source "$CONFIG_FILE"
else
  MODE="AUTO"
fi

resolve_project_path() {
  local input="$1"
  # 絶対パスの場合
  if [[ "$input" == /* ]]; then
    echo "$input"
  else
    echo "$PROJECTS_DIR/$input"
  fi
}

select_project() {
  case "$MODE" in
    FIXED)
      if [ -z "${PROJECT:-}" ]; then
        echo "[project_selector] Error: FIXED mode but PROJECT not set in config/project.conf" >&2
        exit 1
      fi
      local full_path
      full_path=$(resolve_project_path "$PROJECT")
      if [ ! -d "$full_path" ]; then
        echo "[project_selector] Error: プロジェクト '$PROJECT' が見つかりません ($full_path)" >&2
        exit 1
      fi
      echo "$PROJECT"
      ;;
    AUTO)
      local selected
      selected=$(ls -td "$PROJECTS_DIR"/*/ 2>/dev/null | grep -v "OpenCodeSystem" | head -1)
      if [ -z "$selected" ]; then
        echo "[project_selector] Error: プロジェクトが見つかりません" >&2
        exit 1
      fi
      basename "$selected"
      ;;
    *)
      echo "[project_selector] Error: 不明な MODE: $MODE" >&2
      exit 1
      ;;
  esac
}

select_project
