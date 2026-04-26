#!/usr/bin/env bash
# OpenCodeSystem Cron管理インターフェース
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config/project.conf"
PID_FILE="$SCRIPT_DIR/state/pid.txt"
START_SCRIPT="$SCRIPT_DIR/scripts/cron_start.sh"
STOP_SCRIPT="$SCRIPT_DIR/scripts/cron_stop.sh"

# 現在のCron設定を取得
get_cron_entry() {
  local label="$1"
  crontab -l 2>/dev/null | grep "$label" | head -1 || echo ""
}

CRON_START=$(get_cron_entry "cron_start.sh")
CRON_STOP=$(get_cron_entry "cron_stop.sh")

parse_cron_time() {
  local entry="$1"
  if [ -z "$entry" ]; then
    echo "未設定"
    return
  fi
  local min hour day
  min=$(echo "$entry" | awk '{print $1}')
  hour=$(echo "$entry" | awk '{print $2}')
  local dow
  dow=$(echo "$entry" | awk '{print $5}')
  local dow_str
  case "$dow" in
    "1-6") dow_str="月-土" ;;
    "1-5") dow_str="月-金" ;;
    "0,6") dow_str="土-日" ;;
    "0") dow_str="日" ;;
    "1") dow_str="月" ;;
    "2") dow_str="火" ;;
    "3") dow_str="水" ;;
    "4") dow_str="木" ;;
    "5") dow_str="金" ;;
    "6") dow_str="土" ;;
    "*") dow_str="毎日" ;;
    *) dow_str="$dow" ;;
  esac
  printf "%02d:%02d (%s)" "$hour" "$min" "$dow_str"
}

reload_cron() {
  # crontab から既存の OpenCodeSystem 行を削除し、現在の設定で再作成
  local tmpfile
  tmpfile=$(mktemp)
  crontab -l 2>/dev/null | grep -v "cron_start.sh\|cron_stop.sh" > "$tmpfile" || true
  {
    echo "# OpenCodeSystem: ${START_HOUR}:${START_MIN} 起動 (systemd-run)"
    echo "${START_MIN} ${START_HOUR} * * ${START_DOW} ${START_SCRIPT}"
    echo "# OpenCodeSystem: ${STOP_HOUR}:${STOP_MIN} 停止 (systemd + fallback kill)"
    echo "${STOP_MIN} ${STOP_HOUR} * * ${STOP_DOW} ${STOP_SCRIPT}"
  } >> "$tmpfile"
  crontab "$tmpfile"
  rm -f "$tmpfile"
  CRON_START=$(get_cron_entry "cron_start.sh")
  CRON_STOP=$(get_cron_entry "cron_stop.sh")
}

status_indicator() {
  local status="$1"
  if [ "$status" = "有効" ]; then
    echo "●"
  else
    echo "○"
  fi
}

# デフォルト値（現在のCronからパース）
if [ -n "$CRON_START" ]; then
  START_MIN=$(echo "$CRON_START" | awk '{print $1}')
  START_HOUR=$(echo "$CRON_START" | awk '{print $2}')
  START_DOW=$(echo "$CRON_START" | awk '{print $5}')
  CRON_ENABLED=true
else
  START_MIN=30; START_HOUR=8; START_DOW="1-6"
  CRON_ENABLED=false
fi
if [ -n "$CRON_STOP" ]; then
  STOP_MIN=$(echo "$CRON_STOP" | awk '{print $1}')
  STOP_HOUR=$(echo "$CRON_STOP" | awk '{print $2}')
  STOP_DOW=$(echo "$CRON_STOP" | awk '{print $5}')
else
  STOP_MIN=30; STOP_HOUR=16; STOP_DOW="1-6"
fi

# プロジェクト設定読み込み
MODE="AUTO"; PROJECT=""
if [ -f "$CONFIG_FILE" ]; then
  source "$CONFIG_FILE"
fi

while true; do
  clear
  echo "=============================================="
  echo "  OpenCodeSystem Cron 管理"
  echo "=============================================="
  echo ""
  if $CRON_ENABLED; then echo "  Cron: ● 有効"; else echo "  Cron: ○ 無効"; fi
  echo "  ---"
  echo "  起動: $(parse_cron_time "$CRON_START")"
  echo "  停止: $(parse_cron_time "$CRON_STOP")"
  echo "  稼働時間: ${START_HOUR}:${START_MIN} 〜 ${STOP_HOUR}:${STOP_MIN}"
  echo "  ---"
  echo "  モード: $MODE"
  echo "  プロジェクト: ${PROJECT:-"(自動選択)"}"
  echo "  ---"
  if [ -f "$PID_FILE" ]; then
    local pid
    pid=$(cat "$PID_FILE")
    if [ -n "$pid" ] && ps -p "$pid" > /dev/null 2>&1; then
      echo "  状態: ▶ 実行中 (PID $pid)"
    else
      echo "  状態: ■ 停止中"
    fi
  else
    echo "  状態: ■ 停止中"
  fi
  echo ""
  echo "=============================================="
  echo "  1) Cron 有効/無効 切り替え"
  echo "  2) 起動時刻 変更"
  echo "  3) 停止時刻 変更"
  echo "  4) 稼働曜日 変更"
  echo "  5) プロジェクト 変更"
  echo "  6) Cron設定 削除"
  echo "  7) 手動起動 (テスト)"
  echo "  8) 手動停止 (テスト)"
  echo "  9) 状態確認"
  echo "  0) 終了"
  echo "=============================================="
  echo -n "番号を入力: "
  read -r choice

  case "$choice" in
    1)
      if $CRON_ENABLED; then
        crontab -l 2>/dev/null | grep -v "cron_start.sh\|cron_stop.sh" | crontab -
        CRON_ENABLED=false
        CRON_START=""; CRON_STOP=""
        echo "Cron を無効化しました"
      else
        reload_cron
        CRON_ENABLED=true
        echo "Cron を有効化しました"
      fi
      sleep 1
      ;;
    2)
      echo -n "起動時刻 (HH:MM, 例: 08:30): "
      read -r time
      if [[ "$time" =~ ^([0-9]{2}):([0-9]{2})$ ]]; then
        START_HOUR=${BASH_REMATCH[1]}; START_MIN=${BASH_REMATCH[2]}
        reload_cron
        echo "起動時刻を ${START_HOUR}:${START_MIN} に変更しました"
      else
        echo "不正な形式です (HH:MM)"
      fi
      sleep 1
      ;;
    3)
      echo -n "停止時刻 (HH:MM, 例: 16:30): "
      read -r time
      if [[ "$time" =~ ^([0-9]{2}):([0-9]{2})$ ]]; then
        STOP_HOUR=${BASH_REMATCH[1]}; STOP_MIN=${BASH_REMATCH[2]}
        reload_cron
        echo "停止時刻を ${STOP_HOUR}:${STOP_MIN} に変更しました"
      else
        echo "不正な形式です (HH:MM)"
      fi
      sleep 1
      ;;
    4)
      echo "稼働曜日を選択:"
      echo "  1) 月-土 (1-6)"
      echo "  2) 月-金 (1-5)"
      echo "  3) 毎日 (*)"
      echo "  4) 月水金 (1,3,5)"
      echo "  5) 火木土 (2,4,6)"
      echo -n "番号を入力: "
      read -r dow_choice
      case "$dow_choice" in
        1) START_DOW="1-6"; STOP_DOW="1-6" ;;
        2) START_DOW="1-5"; STOP_DOW="1-5" ;;
        3) START_DOW="*"; STOP_DOW="*" ;;
        4) START_DOW="1,3,5"; STOP_DOW="1,3,5" ;;
        5) START_DOW="2,4,6"; STOP_DOW="2,4,6" ;;
        *) echo "未入力のまま"; sleep 1; continue ;;
      esac
      reload_cron
      echo "稼働曜日を変更しました"
      sleep 1
      ;;
    5)
      echo "プロジェクト選択:"
      echo "  1) FIXED (固定プロジェクト)"
      echo "  2) AUTO (最終更新順)"
      echo "  3) プロジェクト一覧から選択"
      echo -n "番号を入力: "
      read -r pmode
      case "$pmode" in
        1)
          echo -n "プロジェクト名 (例: ITIL-Management-System): "
          read -r pname
          if [ -n "$pname" ]; then
            MODE="FIXED"; PROJECT="$pname"
            echo "MODE=FIXED" > "$CONFIG_FILE"
            echo "PROJECT=$PROJECT" >> "$CONFIG_FILE"
            echo "固定プロジェクト: $PROJECT"
          fi
          ;;
        2)
          MODE="AUTO"; PROJECT=""
          echo "MODE=AUTO" > "$CONFIG_FILE"
          echo "自動選択モードに変更しました"
          ;;
        3)
          echo ""
          echo "利用可能なプロジェクト:"
          i=1
          for dir in /home/kensan/Projects/*/; do
            name=$(basename "$dir")
            [ "$name" = "OpenCodeSystem" ] && continue
            echo "  $i) $name"
            i=$((i+1))
          done
          echo -n "番号を入力: "
          read -r psel
          if [[ "$psel" =~ ^[0-9]+$ ]]; then
            idx=0
            for dir in /home/kensan/Projects/*/; do
              name=$(basename "$dir")
              [ "$name" = "OpenCodeSystem" ] && continue
              idx=$((idx+1))
              if [ "$idx" -eq "$psel" ]; then
                MODE="FIXED"; PROJECT="$name"
                echo "MODE=FIXED" > "$CONFIG_FILE"
                echo "PROJECT=$PROJECT" >> "$CONFIG_FILE"
                echo "固定プロジェクト: $PROJECT"
                break
              fi
            done
          fi
          ;;
      esac
      sleep 1
      ;;
    6)
      echo -n "Cron設定を全て削除しますか？ (y/N): "
      read -r confirm
      if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        crontab -l 2>/dev/null | grep -v "cron_start.sh\|cron_stop.sh" | crontab -
        CRON_ENABLED=false; CRON_START=""; CRON_STOP=""
        echo "Cron設定を削除しました"
      fi
      sleep 1
      ;;
    7)
      echo "手動起動を実行します..."
      bash "$START_SCRIPT" || echo "起動に失敗しました"
      sleep 2
      ;;
    8)
      echo "手動停止を実行します..."
      bash "$STOP_SCRIPT" || echo "停止に失敗しました"
      sleep 2
      ;;
    9)
      echo ""
      echo "--- 状態 ---"
      if [ -f "$PID_FILE" ]; then
        pid=$(cat "$PID_FILE")
        if [ -n "$pid" ] && ps -p "$pid" > /dev/null 2>&1; then
          echo "  実行中: PID $pid"
          ps -p "$pid" -o pid,etime,%cpu,%mem,args --no-headers 2>/dev/null || true
        else
          echo "  停止中 (PID ファイル残)"
        fi
      else
        echo "  停止中"
      fi
      echo ""
      echo "--- 最新ログ ---"
      tail -3 "$SCRIPT_DIR/logs/cron.log" 2>/dev/null || echo "  (ログなし)"
      echo ""
      echo "--- systemd ---"
      systemctl --user is-active opencode-run 2>/dev/null || echo "  (停止中)"
      echo -n "Enter で戻る..."
      read -r
      ;;
    0)
      echo "終了します"
      exit 0
      ;;
    *)
      echo "無効な選択です"
      sleep 1
      ;;
  esac
done
