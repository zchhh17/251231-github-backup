#!/usr/bin/env bash
set -Eeuo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_ROOT="$BASE_DIR/work"
BACKUP_DIR="$WORK_ROOT/backup-repo"

INDEX_JSON="$BACKUP_DIR/index.json"

[[ -d "$BACKUP_DIR/.git" ]] || {
  echo "❌ backup-repo 不存在或不是 git 仓库"
  exit 1
}

tmp="$(mktemp)"

echo "🔎 收集 report.json ..."

find "$WORK_ROOT" -type f -path "*/_pkg/report.json" \
  | sort \
  | while read -r report; do
      jq '.' "$report"
    done \
  | jq -s '{
      generated_at: (now | todate),
      total: length,
      items: sort_by(.timestamp) | reverse
    }' > "$tmp"

mv "$tmp" "$INDEX_JSON"

cd "$BACKUP_DIR"
git add index.json
git commit -m "chore: update index.json"
git push

echo "✅ index.json 已生成并提交"
echo "📍 $INDEX_JSON"
