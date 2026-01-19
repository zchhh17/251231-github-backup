#!/usr/bin/env bash
set -euo pipefail

# ====== 配置区 ======
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_ROOT="$BASE_DIR/work"
KEEP_DAYS=3          # 保留最近 N 天
DRY_RUN=1            # 1=只显示不删除，0=真正删除
# ====================

echo "🧹 清理 work/ （保留最近 $KEEP_DAYS 天）"
[[ "$DRY_RUN" == "1" ]] && echo "⚠️ DRY-RUN 模式（不会真的删除）"

# ---------- Path Lock ----------
[[ -d "$WORK_ROOT" ]] || {
  echo "❌ work 目录不存在：$WORK_ROOT"
  exit 1
}

[[ "$WORK_ROOT" == "/" || -z "$WORK_ROOT" ]] && {
  echo "❌ 非法路径：$WORK_ROOT"
  exit 99
}

NOW_SEC="$(date +%s)"

cd "$WORK_ROOT"

# ---------- 扫描 ----------
for d in */; do
  dir="${d%/}"

  # 跳过集中仓库
  [[ "$dir" == "backup-repo" ]] && continue

  # 只允许 repo-YYYYMMDD-HHMMSS
  if [[ ! "$dir" =~ -[0-9]{8}-[0-9]{6}$ ]]; then
    echo "⏭ 跳过（不匹配规则）：$dir"
    continue
  fi

  ts="${dir##*-}"
  date_part="${ts:0:8}"
  time_part="${ts:8:6}"

  if ! dir_sec="$(date -d "${date_part} ${time_part:0:2}:${time_part:2:2}:${time_part:4:2}" +%s 2>/dev/null)"; then
    echo "⏭ 跳过（无法解析时间）：$dir"
    continue
  fi

  age_days=$(( (NOW_SEC - dir_sec) / 86400 ))

  if (( age_days >= KEEP_DAYS )); then
    if [[ "$DRY_RUN" == "1" ]]; then
      echo "🟡 [DRY] 将删除：$dir  (${age_days} 天前)"
    else
      echo "🗑 删除：$dir  (${age_days} 天前)"
      rm -rf --one-file-system "$dir"
    fi
  else
    echo "✅ 保留：$dir  (${age_days} 天前)"
  fi
done
