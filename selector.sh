#!/usr/bin/env bash
# プロジェクト選択
set -euo pipefail

PROJECTS_DIR="/home/kensan/Projects"

echo ""
echo "利用可能なプロジェクト:"
echo "----------------------"

PROJECTS=()
i=1
for dir in "$PROJECTS_DIR"/*/; do
  name=$(basename "$dir")
  [ "$name" = "OpenCodeSystem" ] && continue
  PROJECTS+=("$name")
  echo "  $i) $name"
  i=$((i + 1))
done

if [ ${#PROJECTS[@]} -eq 0 ]; then
  echo "Error: プロジェクトが見つかりません"
  exit 1
fi

echo ""
echo -n "番号を入力してください (1-${#PROJECTS[@]}): "
read -r selection

if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt "${#PROJECTS[@]}" ]; then
  echo "Error: 不正な選択です"
  exit 1
fi

TARGET_PROJECT="${PROJECTS[$((selection - 1))]}"
export TARGET_PROJECT

echo "選択: $TARGET_PROJECT"
echo "{ \"project\": \"$TARGET_PROJECT\", \"phase\": \"monitor\", \"retry\": 0, \"task\": \"\", \"status\": \"running\" }" > "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/state/state.json"
echo "state initialized."
