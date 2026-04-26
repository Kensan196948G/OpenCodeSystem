#!/usr/bin/env bash
# OpenCodeSystem 総合メニュー
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config/project.conf"
CRON_PROJECTS_FILE="$SCRIPT_DIR/config/cron_projects.conf"
PID_FILE="$SCRIPT_DIR/state/pid.txt"
STATE_FILE="$SCRIPT_DIR/state/state.json"
LOG_DIR="$SCRIPT_DIR/logs"
START_SCRIPT="$SCRIPT_DIR/scripts/cron_start.sh"
STOP_SCRIPT="$SCRIPT_DIR/scripts/cron_stop.sh"

DOW_NAMES=("日" "月" "火" "水" "木" "金" "土")

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

# プロジェクト個別Cron設定を読み込み
load_cron_projects() {
  CRON_PROJECTS=()
  if [ -f "$CRON_PROJECTS_FILE" ]; then
    while IFS='=' read -r dow proj; do
      [[ "$dow" =~ ^#.*$ || -z "$dow" || -z "$proj" ]] && continue
      CRON_PROJECTS+=("$dow=$proj")
    done < "$CRON_PROJECTS_FILE"
  fi
}
load_cron_projects

has_per_project() {
  [ ${#CRON_PROJECTS[@]} -gt 0 ]
}

reload_cron() {
  local tmp; tmp=$(mktemp)
  crontab -l 2>/dev/null | grep -v "cron_start.sh\|cron_stop.sh" > "$tmp" || true

  if has_per_project; then
    # プロジェクト個別Cronを生成
    for entry in "${CRON_PROJECTS[@]}"; do
      local dow proj
      IFS='=' read -r dow proj <<< "$entry"
      echo "# OPENCODE project=${proj} dow=${dow}" >> "$tmp"
      echo "${START_MIN} ${START_HOUR} * * ${dow} ${START_SCRIPT} ${proj}" >> "$tmp"
    done
  else
    # 従来の単一Cron
    echo "# OpenCodeSystem: ${START_HOUR}:${START_MIN} 起動" >> "$tmp"
    echo "${START_MIN} ${START_HOUR} * * ${START_DOW} ${START_SCRIPT}" >> "$tmp"
  fi
  echo "# OpenCodeSystem: ${STOP_HOUR}:${STOP_MIN} 停止" >> "$tmp"
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

# プロジェクト個別Cron設定を書き出し
save_cron_projects() {
  > "$CRON_PROJECTS_FILE"
  echo "# OpenCodeSystem プロジェクト個別Cron設定" >> "$CRON_PROJECTS_FILE"
  echo "# 書式: 曜日番号=プロジェクト名" >> "$CRON_PROJECTS_FILE"
  echo "# 曜日: 0=日 1=月 2=火 3=水 4=木 5=金 6=土" >> "$CRON_PROJECTS_FILE"
  echo "" >> "$CRON_PROJECTS_FILE"
  for entry in "${CRON_PROJECTS[@]}"; do
    echo "$entry" >> "$CRON_PROJECTS_FILE"
  done
}

list_projects() {
  local i=0
  for dir in /home/kensan/Projects/*/; do
    n=$(basename "$dir"); [ "$n" = "OpenCodeSystem" ] && continue
    echo "  $((i+1))) $n"
    PROJECT_LIST[$i]="$n"
    i=$((i+1))
  done
  [ "$i" -eq 0 ] && echo "  (プロジェクトなし)"
  TOTAL_PROJECTS=$i
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
  if has_per_project; then
    echo "  ◆  スケジュール: 曜日別プロジェクト登録済 (${#CRON_PROJECTS[@]}件)"
  else
    echo "  ◆  スケジュール: ${START_HOUR}:${START_MIN} → ${STOP_HOUR}:${STOP_MIN} ($(dow_label "$START_DOW"))"
  fi
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
  echo "    6) 起動・停止時刻 変更"
  echo "    7) プロジェクト個別Cron 管理"
  echo "    8) Cron設定 削除"
  echo ""
  echo "  [プロジェクト設定]"
  echo "    9)  プロジェクト 変更"
  echo "    10) プロジェクト一覧 表示"
  echo ""
  echo "  [情報]"
  echo "    11) 状態確認（PID / ログ / systemd）"
  echo "    12) 最新ログ 表示"
  echo "    13) state.json 表示"
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
      if has_per_project; then
        for entry in "${CRON_PROJECTS[@]}"; do
          IFS='=' read -r dow proj <<< "$entry"
          printf "    ▶ %s %s:%s  (%s)  %s\n" "${DOW_NAMES[$dow]}" "$START_HOUR" "$START_MIN" "$(dow_label "$dow")" "$proj"
        done
      else
        crontab -l 2>/dev/null | grep "cron_start.sh" | while read -r line; do
          m=$(echo "$line" | awk '{print $1}')
          h=$(echo "$line" | awk '{print $2}')
          d=$(echo "$line" | awk '{print $5}')
          printf "    ▶ 起動  %s:%s  (%s)  [%s] %s\n" "$h" "$m" "$(dow_label "$d")" "$MODE" "${PROJECT:-自動}"
        done
      fi
      crontab -l 2>/dev/null | grep "cron_stop.sh" | while read -r line; do
        m=$(echo "$line" | awk '{print $1}')
        h=$(echo "$line" | awk '{print $2}')
        d=$(echo "$line" | awk '{print $5}')
        printf "    ■ 停止  %s:%s  (%s)\n" "$h" "$m" "$(dow_label "$d")"
      done
      [ -z "$(crontab -l 2>/dev/null | grep "cron_start.sh")" ] && echo "    (登録なし)"
      echo ""
      echo "  ◆ その他 Cronジョブ"
      echo "  ────────────────────────────────────────────────────────"
      crontab -l 2>/dev/null | grep -v "cron_start.sh\|cron_stop.sh" | grep -v '^#' | grep -v '^$' | while read -r line; do
        [ -z "$line" ] && continue
        m=$(echo "$line" | awk '{print $1}')
        h=$(echo "$line" | awk '{print $2}')
        cmd=$(echo "$line" | cut -d' ' -f6-)
        sched=""
        [ "$m" != "*" ] && sched="${m}分 "
        [ "$h" != "*" ] && sched="${sched}${h}時"
        [ -z "$sched" ] && sched="毎分"
        sched=$(echo "$sched" | xargs)
        printf "    %-12s %s\n" "$sched" "${cmd:0:70}"
      done
      [ -z "$(crontab -l 2>/dev/null | grep -v "cron_start.sh\|cron_stop.sh" | grep -v '^#' | grep -v '^$')" ] && echo "    ジョブなし"
      echo ""
      echo "  ◆ コメント行"
      echo "  ────────────────────────────────────────────────────────"
      crontab -l 2>/dev/null | grep '^#' | head -10 | while read -r line; do
        echo "    $line"
      done
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
      else echo "不正な形式"; sleep 1; continue; fi
      echo -n "停止時刻 (HH:MM, 例: 16:30): "
      read -r t
      if [[ "$t" =~ ^([0-9]{2}):([0-9]{2})$ ]]; then
        STOP_HOUR=${BASH_REMATCH[1]}; STOP_MIN=${BASH_REMATCH[2]}
      else echo "不正な形式"; sleep 1; continue; fi
      echo -n "稼働曜日 (1=月-土 2=月-金 3=毎日): "
      read -r d
      case "$d" in 1) START_DOW="1-6";; 2) START_DOW="1-5";; 3) START_DOW="*";; *) echo "維持";; esac
      STOP_DOW="$START_DOW"
      reload_cron
      echo "変更しました: ${START_HOUR}:${START_MIN} → ${STOP_HOUR}:${STOP_MIN} ($(dow_label "$START_DOW"))"
      sleep 1
      ;;
    7)
      while true; do
        echo ""
        echo "╔══════════════════════════════════════════════════════════╗"
        echo "║           プロジェクト個別Cron 管理                     ║"
        echo "╚══════════════════════════════════════════════════════════╝"
        echo ""
        if has_per_project; then
          echo "  登録中:"
          for entry in "${CRON_PROJECTS[@]}"; do
            IFS='=' read -r dow proj <<< "$entry"
            echo "     ${DOW_NAMES[$dow]}曜日 → $proj"
          done
        else
          echo "  登録なし（単一Cron: $(dow_label "$START_DOW") ${START_HOUR}:${START_MIN}）"
        fi
        echo ""
        echo "  1) 曜日とプロジェクトを追加"
        echo "  2) 登録を削除"
        echo "  3) 全てクリア（単一Cronに戻す）"
        echo "  0) 戻る"
        echo -n "  番号: "
        read -r sub
        case "$sub" in
          1)
            echo "  曜日を選択:"
            echo "    1=月 2=火 3=水 4=木 5=金 6=土"
            echo -n "  番号: "
            read -r dow_num
            [ "$dow_num" -lt 1 ] || [ "$dow_num" -gt 6 ] && echo "  不正"; sleep 1; continue
            PROJECT_LIST=(); TOTAL_PROJECTS=0
            echo "  プロジェクト:"
            list_projects
            [ "$TOTAL_PROJECTS" -eq 0 ] && sleep 1; continue
            echo -n "  番号: "
            read -r psel
            [ "$psel" -lt 1 ] || [ "$psel" -gt "$TOTAL_PROJECTS" ] && echo "  不正"; sleep 1; continue
            # 同じ曜日の既存登録があれば上書き
            local new_entry="${dow_num}=${PROJECT_LIST[$((psel-1))]}"
            local found=false
            for i in "${!CRON_PROJECTS[@]}"; do
              if [[ "${CRON_PROJECTS[$i]}" == "${dow_num}="* ]]; then
                CRON_PROJECTS[$i]="$new_entry"
                found=true
                break
              fi
            done
            $found || CRON_PROJECTS+=("$new_entry")
            save_cron_projects
            reload_cron
            echo "  登録しました: ${DOW_NAMES[$dow_num]}曜日 → ${PROJECT_LIST[$((psel-1))]}"
            sleep 1
            ;;
          2)
            [ ${#CRON_PROJECTS[@]} -eq 0 ] && echo "  登録なし"; sleep 1; continue
            echo "  削除する番号を選択:"
            for i in "${!CRON_PROJECTS[@]}"; do
              IFS='=' read -r dow proj <<< "${CRON_PROJECTS[$i]}"
              echo "    $((i+1))) ${DOW_NAMES[$dow]}曜日 → $proj"
            done
            echo -n "  番号: "
            read -r del
            [ "$del" -lt 1 ] || [ "$del" -gt "${#CRON_PROJECTS[@]}" ] && echo "  不正"; sleep 1; continue
            unset "CRON_PROJECTS[$((del-1))]"
            CRON_PROJECTS=("${CRON_PROJECTS[@]}")
            save_cron_projects
            reload_cron
            echo "  削除しました"
            sleep 1
            ;;
          3)
            echo -n "  全てクリアして単一Cronに戻しますか？ (y/N): "
            read -r c
            if [ "$c" = "y" ] || [ "$c" = "Y" ]; then
              CRON_PROJECTS=()
              > "$CRON_PROJECTS_FILE"
              reload_cron
              echo "  クリアしました"
            fi
            sleep 1
            ;;
          0) break ;;
          *) echo "  無効"; sleep 1 ;;
        esac
      done
      ;;
    8)
      echo -n "Cron設定を全て削除しますか？ (y/N): "
      read -r c
      if [ "$c" = "y" ] || [ "$c" = "Y" ]; then
        crontab -l 2>/dev/null | grep -v "cron_start.sh\|cron_stop.sh" | crontab -
        CRON_ENABLED=false; CRON_START=""; CRON_STOP=""
        echo "削除しました"
      fi
      sleep 1
      ;;
    9)
      echo "  1) FIXED（固定） 2) AUTO（自動） 3) 一覧から選択"
      echo -n "番号: "; read -r pm
      case "$pm" in
        1)
          echo -n "プロジェクト名: "; read -r pn
          if [ -n "$pn" ]; then MODE="FIXED"; PROJECT="$pn"; fi
          ;;
        2) MODE="AUTO"; PROJECT="" ;;
        3)
          PROJECT_LIST=(); TOTAL_PROJECTS=0
          list_projects
          [ "$TOTAL_PROJECTS" -eq 0 ] && sleep 1; continue
          echo -n "番号: "; read -r ps
          if [[ "$ps" =~ ^[0-9]+$ ]] && [ "$ps" -ge 1 ] && [ "$ps" -le "$TOTAL_PROJECTS" ]; then
            MODE="FIXED"; PROJECT="${PROJECT_LIST[$((ps-1))]}"
          fi
          ;;
      esac
      echo "MODE=$MODE" > "$CONFIG_FILE"
      echo "PROJECT=$PROJECT" >> "$CONFIG_FILE"
      sleep 1
      ;;
    10)
      echo ""
      echo "--- 利用可能なプロジェクト ---"
      for dir in /home/kensan/Projects/*/; do
        n=$(basename "$dir"); [ "$n" = "OpenCodeSystem" ] && continue
        echo "  $n"
      done
      echo -n "Enter で戻る..."; read -r
      ;;
    11)
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
        if has_per_project; then
          echo "  ● 有効 (個別登録 ${#CRON_PROJECTS[@]}件)"
          for entry in "${CRON_PROJECTS[@]}"; do
            IFS='=' read -r dow proj <<< "$entry"
            echo "     ${DOW_NAMES[$dow]}曜日 ${START_HOUR}:${START_MIN} → $proj"
          done
        else
          echo "  ● 有効 ($(dow_label "$START_DOW") ${START_HOUR}:${START_MIN} → ${STOP_HOUR}:${STOP_MIN})"
        fi
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
    12)
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
    13)
      echo ""
      cat "$STATE_FILE" 2>/dev/null | jq . 2>/dev/null || echo "(state.json なし)"
      echo -n "Enter で戻る..."; read -r
      ;;
    0) echo "終了します"; exit 0 ;;
    *) echo "無効な選択です"; sleep 1 ;;
  esac
done
