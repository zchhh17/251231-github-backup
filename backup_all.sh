#!/usr/bin/env bash
set -Eeuo pipefail

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_LIST="$BASE_DIR/repos.txt"
LOG_DIR="$BASE_DIR/logs"
WORK_ROOT="$BASE_DIR/work"

mkdir -p "$LOG_DIR" "$WORK_ROOT"

[[ -f "$REPO_LIST" ]] || {
  echo "❌ repos.txt 不存在"
  exit 1
}

SUCCESS=()
FAILED=()

while read -r repo_url; do
  [[ -z "$repo_url" || "$repo_url" =~ ^# ]] && continue

  owner="$(basename "$(dirname "$repo_url")")"
  repo="$(basename "$repo_url" .git)"
  REPO_ID="${owner}__${repo}"

  echo "📦 备份：$REPO_ID"

  if REPO_NAME="$REPO_ID" \
     bash "$BASE_DIR/backup_one.sh" "$repo_url"; then
    SUCCESS+=("$repo_url")
  else
    FAILED+=("$repo_url")
  fi

  echo "----------------------------"
done < "$REPO_LIST"

echo
echo "✅ 成功仓库：${#SUCCESS[@]}"
printf '  ✔ %s\n' "${SUCCESS[@]}"

if (( ${#FAILED[@]} > 0 )); then
  echo
  echo "❌ 失败仓库：${#FAILED[@]}"
  printf '  ✘ %s\n' "${FAILED[@]}"
  exit 1
fi
