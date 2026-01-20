#!/usr/bin/env bash
set -Eeuo pipefail

# ===== 可配置项 =====
KEEP_DAYS="${KEEP_DAYS:-7}"     # 默认保留 7 天
DRY_RUN="${DRY_RUN:-0}"         # 1 = 只打印不删除

# ===================
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_ROOT="$BASE_DIR/work"

[[ -d "$WORK_ROOT" ]] || {
  echo "❌ work 目录不存在"
  exit 1
}

echo "🧹 清理 work 目录"
echo "➡️ 保留天数：$KEEP_DAYS"
echo "➡️ DRY_RUN：$DRY_RUN"
echo

now="$(date +%s)"
deleted=0

find "$WORK_ROOT" -mindepth 2 -maxdepth 2 -type d \
  ! -path "$WORK_ROOT/backup-repo/*" \
  | while read -r dir; do

    # 取目录 mtime
    mtime="$(stat -c %Y "$dir")"
    age_days=$(( (now - mtime) / 86400 ))

    if (( age_days >= KEEP_DAYS )); then
      if (( DRY_RUN == 1 )); then
        echo "🟡 将删除（$age_days 天）：$dir"
      else
        echo "🔴 删除（$age_days 天）：$dir"
        rm -rf "$dir"
        ((deleted++))
      fi
    fi
done

echo
if (( DRY_RUN == 1 )); then
  echo "✅ 干跑完成（未实际删除）"
else
  echo "✅ 清理完成，删除 $deleted 个目录"
fi
