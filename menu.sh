#!/usr/bin/env bash
# OpenCodeSystem 総合メニュー
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config/project.conf"
PID_FILE="$SCRIPT_DIR/state/pid.txt"
STATE_FILE="$SCRIPT_DIR/state/state.json"
LOG_DIR="$SCRIPT_DIR/logs"
START_SCRIPT="$SCRIPT_DIR/scripts/cron_start.sh"
STOP_SCRIPT="$SCRIPT_DIR/scripts/cron_stop.sh"

get_cron_entry() {
  crontab -l 2>/dev/null | grep "$1" | head -1 || echo ""
}
CRON_START=$(get_cron_entry "cron_start.sh")
CRON_STOP=$(get_cron_entry "cron_stop.sh")

if [ -n "$CRON_START" ]; then
  CRON_ENABLED=true
  START_MIN=$(echo "$CRON_START" | awk '{print $1}')
  START_HOUR=$(echo "$CRON_START" | awk '{print $2}')
  START_DOW=$(echo "$CRON_START" | awk '{print $5}')
  STOP_MIN=$(echo "$CRON_STOP" | awk '{print $1}')
  STOP_HOUR=$(echo "$CRON_STOP" | awk '{print $2}')
  STOP_DOW=$(echo "$CRON_STOP" | awk '{print $5}')
else
  CRON_ENABLED=false
  START_MIN=30; START_HOUR=8; START_DOW="1-6"
  STOP_MIN=30; STOP_HOUR=16; STOP_DOW="1-6"
fi

MODE="AUTO"; PROJECT=""
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

dow_label() {
  case "$1" in "1-6") echo "月-土";; "1-5") echo "月-金";; "*") echo "毎日";;
    "1,3,5") echo "月水金";; "2,4,6") echo "火木土";; *) echo "$1";; esac
}

reload_cron() {
  local tmp; tmp=$(mktemp)
  crontab -l 2>/dev/null | grep -v "cron_start.sh\|cron_stop.sh" > "$tmp" || true
  echo "# OpenCodeSystem: ${START_HOUR}:${START_MIN} 起動 (systemd-run)" >> "$tmp"
  echo "${START_MIN} ${START_HOUR} * * ${START_DOW} ${START_SCRIPT}" >> "$tmp"
  echo "# OpenCodeSystem: ${STOP_HOUR}:${STOP_MIN} 停止 (systemd + fallback kill)" >> "$tmp"
  echo "${STOP_MIN} ${STOP_HOUR} * * ${STOP_DOW} ${STOP_SCRIPT}" >> "$tmp"
  crontab "$tmp"; rm -f "$tmp"
  CRON_START=$(get_cron_entry "cron_start.sh")
  CRON_STOP=$(get_cron_entry "cron_stop.sh")
}

is_running() {
  if [ -f "$PID_FILE" ]; then
    local pid; pid=$(cat "$PID_FILE")
    [ -n "$pid" ] && ps -p "$pid" > /dev/null 2>&1 && return 0
  fi
  systemctl --user is-active opencode-run > /dev/null 2>&1 && return 0
  return 1
}

while true; do
  clear
  echo "=============================================="
  echo "  OpenCodeSystem 総合メニュー"
  echo "=============================================="
  echo ""
  if is_running; then
    echo "  ◆  状態: ▶  実行中 (PID $(cat "$PID_FILE" 2>/dev/null || echo "?")"
  else
    echo "  ◆  状態: ■  停止中"
  fi
  echo "  ◆  Cron: $(if $CRON_ENABLED; then echo '● 有効'; else echo '○ 無効'; fi)"
  echo "  ◆  スケジュール: ${START_HOUR}:${START_MIN} → ${STOP_HOUR}:${STOP_MIN} ($(dow_label "$START_DOW"))"
  echo "  ◆  モード: $MODE  /  プロジェクト: ${PROJECT:-自動選択}"
  echo "=============================================="
  echo ""
  echo "  [実行]"
  echo "    1) OpenCodeSystem を起動（プロジェクト選択）"
  echo "    2) 手動起動（cron_start.sh）"
  echo "    3) 手動停止（cron_stop.sh）"
  echo ""
  echo "  [Cron 設定]"
  echo "    4) 登録一覧 表示"
  echo "    5) Cron 有効/無効 切り替え"
  echo "    6) 起動時刻 変更"
  echo "    7) 停止時刻 変更"
  echo "    8) 稼働曜日 変更"
  echo "    9) Cron設定 削除"
  echo ""
  echo "  [プロジェクト設定]"
  echo "    10) プロジェクト 変更"
  echo "    11) プロジェクト一覧 表示"
  echo ""
  echo "  [情報]"
  echo "    12) 状態確認（PID / ログ / systemd）"
  echo "    13) 最新ログ 表示"
  echo "    14) state.json 表示"
  echo ""
  echo "  0) 終了"
  echo "=============================================="
  echo -n "番号を入力: "
  read -r choice

  case "$choice" in
    1)
      bash "$SCRIPT_DIR/launcher.sh"
      echo -n "Enter で戻る..."; read -r
      ;;
    2)
      bash "$START_SCRIPT"
      sleep 2
      ;;
    3)
      bash "$STOP_SCRIPT"
      sleep 2
      ;;
    4)
      echo ""
      echo "╔══════════════════════════════════════════════════════════╗"
      echo "║                 Cron 登録一覧                           ║"
      echo "╚══════════════════════════════════════════════════════════╝"
      echo ""
      echo "  ◆ OpenCodeSystem"
      echo "  ────────────────────────────────────────────────────────"
      crontab -l 2>/dev/null | grep "cron_start.sh" | while read -r line; do
        m=$(echo "$line" | awk '{print $1}')
        h=$(echo "$line" | awk '{print $2}')
        d=$(echo "$line" | awk '{print $5}')
        printf "    %-7s %s:%s  (%s)  [%s] %s\n" "▶ 起動" "$h" "$m" "$(dow_label "$d")" "$MODE" "${PROJECT:-自動}"
      done
      crontab -l 2>/dev/null | grep "cron_stop.sh" | while read -r line; do
        m=$(echo "$line" | awk '{print $1}')
        h=$(echo "$line" | awk '{print $2}')
        d=$(echo "$line" | awk '{print $5}')
        printf "    %-7s %s:%s  (%s)\n" "■ 停止" "$h" "$m" "$(dow_label "$d")"
      done
      [ -z "$(crontab -l 2>/dev/null | grep "cron_start.sh")" ] && echo "    (登録なし)"
      echo ""
      echo "  ◆ その他 Cronジョブ"
      echo "  ────────────────────────────────────────────────────────"
      echo ""
      crontab -l 2>/dev/null | grep -v "cron_start.sh\|cron_stop.sh" | grep -v '^#' | grep -v '^$' | while read -r line; do
        [ -z "$line" ] && continue
        m=$(echo "$line" | awk '{print $1}')
        h=$(echo "$line" | awk '{print $2}')
        d=$(echo "$line" | awk '{print $3}')
        dm=$(echo "$line" | awk '{print $4}')
        dw=$(echo "$line" | awk '{print $5}')
        cmd=$(echo "$line" | cut -d' ' -f6-)
        sched=""
        if [ "$m" != "*" ]; then sched="${m}分 "; fi
        if [ "$h" != "*" ]; then sched="${sched}${h}時"; fi
        [ -z "$sched" ] && sched="毎分"
        sched=$(echo "$sched" | xargs)
        printf "    %-12s %s\n" "$sched" "${cmd:0:70}"
      done
      [ -z "$(crontab -l 2>/dev/null | grep -v "cron_start.sh\|cron_stop.sh" | grep -v '^#' | grep -v '^$')" ] && echo "    ジョブなし"
      echo ""
      echo "  ◆ コメント行"
      echo "  ────────────────────────────────────────────────────────"
      crontab -l 2>/dev/null | grep '^#' | while read -r line; do
        echo "    $line"
      done
      [ -z "$(crontab -l 2>/dev/null | grep '^#')" ] && echo "    (なし)"
      echo ""
      echo "╔══════════════════════════════════════════════════════════╗"
      echo "║ 凡例:  ▶ 実行中  ■ 停止中                             ║"
      echo "╚══════════════════════════════════════════════════════════╝"
      echo -n "Enter で戻る..."; read -r
      ;;
    5)
      if $CRON_ENABLED; then
        crontab -l 2>/dev/null | grep -v "cron_start.sh\|cron_stop.sh" | crontab -
        CRON_ENABLED=false; CRON_START=""; CRON_STOP=""
        echo "Cron を無効化しました"
      else
        reload_cron; CRON_ENABLED=true
        echo "Cron を有効化しました"
      fi
      sleep 1
      ;;
    6)
      echo -n "起動時刻 (HH:MM, 例: 08:30): "
      read -r t
      if [[ "$t" =~ ^([0-9]{2}):([0-9]{2})$ ]]; then
        START_HOUR=${BASH_REMATCH[1]}; START_MIN=${BASH_REMATCH[2]}
        reload_cron; echo "変更しました"
      else echo "不正な形式"; fi
      sleep 1
      ;;
    7)
      echo -n "停止時刻 (HH:MM, 例: 16:30): "
      read -r t
      if [[ "$t" =~ ^([0-9]{2}):([0-9]{2})$ ]]; then
        STOP_HOUR=${BASH_REMATCH[1]}; STOP_MIN=${BASH_REMATCH[2]}
        reload_cron; echo "変更しました"
      else echo "不正な形式"; fi
      sleep 1
      ;;
    8)
      echo "  1) 月-土  2) 月-金  3) 毎日  4) 月水金  5) 火木土"
      echo -n "番号: "; read -r d
      case "$d" in 1) START_DOW="1-6";; 2) START_DOW="1-5";; 3) START_DOW="*";; 4) START_DOW="1,3,5";; 5) START_DOW="2,4,6";; *) sleep 1; continue;; esac
      STOP_DOW="$START_DOW"; reload_cron; echo "変更しました"
      sleep 1
      ;;
    9)
      echo -n "Cron設定を全て削除しますか？ (y/N): "
      read -r c
      if [ "$c" = "y" ] || [ "$c" = "Y" ]; then
        crontab -l 2>/dev/null | grep -v "cron_start.sh\|cron_stop.sh" | crontab -
        CRON_ENABLED=false; CRON_START=""; CRON_STOP=""
        echo "削除しました"
      fi
      sleep 1
      ;;
    10)
      echo "  1) FIXED（固定） 2) AUTO（自動） 3) 一覧から選択"
      echo -n "番号: "; read -r pm
      case "$pm" in
        1)
          echo -n "プロジェクト名: "; read -r pn
          if [ -n "$pn" ]; then MODE="FIXED"; PROJECT="$pn"; fi
          ;;
        2) MODE="AUTO"; PROJECT="" ;;
        3)
          i=1
          for dir in /home/kensan/Projects/*/; do
            n=$(basename "$dir"); [ "$n" = "OpenCodeSystem" ] && continue
            echo "  $i) $n"; i=$((i+1))
          done
          echo -n "番号: "; read -r ps
          if [[ "$ps" =~ ^[0-9]+$ ]]; then
            idx=0
            for dir in /home/kensan/Projects/*/; do
              n=$(basename "$dir"); [ "$n" = "OpenCodeSystem" ] && continue
              idx=$((idx+1))
              if [ "$idx" -eq "$ps" ]; then MODE="FIXED"; PROJECT="$n"; break; fi
            done
          fi
          ;;
      esac
      echo "MODE=$MODE" > "$CONFIG_FILE"
      echo "PROJECT=$PROJECT" >> "$CONFIG_FILE"
      sleep 1
      ;;
     11)
      echo ""
      echo "--- 利用可能なプロジェクト ---"
      for dir in /home/kensan/Projects/*/; do
        n=$(basename "$dir"); [ "$n" = "OpenCodeSystem" ] && continue
        echo "  $n"
      done
      echo -n "Enter で戻る..."; read -r
      ;;
     12)
      echo ""
      echo "--- 状態 ---"
      if is_running; then
        pid=$(cat "$PID_FILE" 2>/dev/null || echo "?")
        echo "  状態: ▶ 実行中 (PID $pid)"
        ps -p "$pid" -o pid,etime,%cpu,%mem,args --no-headers 2>/dev/null || true
      else
        echo "  状態: ■ 停止中"
      fi
      echo ""
      echo "--- Cron ---"
      if $CRON_ENABLED; then
        echo "  ● 有効 ($(echo "$CRON_START" | awk '{print $1" "$2}') → $(echo "$CRON_STOP" | awk '{print $1" "$2}'))"
      else
        echo "  ○ 無効"
      fi
      echo ""
      echo "--- systemd ---"
      systemctl --user is-active opencode-run 2>/dev/null || echo "  (停止中)"
      echo ""
      echo "--- 最新ログ (cron.log) ---"
      tail -5 "$LOG_DIR/cron.log" 2>/dev/null || echo "  (ログなし)"
      echo -n "Enter で戻る..."; read -r
      ;;
     13)
      echo ""
      echo "ログを選択:"
      echo "  1) cron.log  2) start.log  3) stop.log"
      echo -n "番号: "; read -r lc
      case "$lc" in
        1) f="cron.log";; 2) f="start.log";; 3) f="stop.log";;
        *) sleep 1; continue;;
      esac
      echo ""
      tail -20 "$LOG_DIR/$f" 2>/dev/null || echo "(ログなし)"
      echo -n "Enter で戻る..."; read -r
      ;;
     14)
      echo ""
      cat "$STATE_FILE" 2>/dev/null | jq . 2>/dev/null || echo "(state.json なし)"
      echo -n "Enter で戻る..."; read -r
      ;;
    0) echo "終了します"; exit 0 ;;
    *) echo "無効な選択です"; sleep 1 ;;
  esac
done
