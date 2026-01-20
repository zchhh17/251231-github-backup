#!/usr/bin/env bash
set -Eeuo pipefail

: "${GITHUB_TOKEN:=}"

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_ROOT="$BASE_DIR/work"
REPOS_FILE="$BASE_DIR/repos.txt"
INDEX_JSON="$WORK_ROOT/index.json"

mkdir -p "$WORK_ROOT"

if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
  git config --global user.name "github-actions[bot]"
  git config --global user.email "github-actions[bot]@users.noreply.github.com"
  git remote set-url origin \
    "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"
fi

SUCCESS=()
FAILED=()

while read -r repo; do
  [[ -z "$repo" || "$repo" =~ ^# ]] && continue

  if ./backup_one.sh "$repo"; then
    SUCCESS+=("$repo")
  else
    FAILED+=("$repo")
  fi
  echo "----------------------------"
done < "$REPOS_FILE"

# ===== index.json =====
jq -s '{
  generated_at: now | strftime("%Y-%m-%d %H:%M:%S"),
  items: .
}' "$WORK_ROOT"/*/*/report.json > "$INDEX_JSON"

git add work
git commit -m "backup(all): $(date '+%Y%m%d-%H%M%S')" || true
git push

TAG="backup-$(date '+%Y%m%d-%H%M%S')"
git tag "$TAG"
git push origin "$TAG"

# ===== 清理 7 天前 =====
find "$WORK_ROOT" -mindepth 2 -maxdepth 2 -type d -mtime +7 -exec rm -rf {} +

echo
echo "✅ 成功仓库：${#SUCCESS[@]}"
printf '  ✔ %s\n' "${SUCCESS[@]:-}"

echo
echo "❌ 失败仓库：${#FAILED[@]}"
printf '  ✘ %s\n' "${FAILED[@]:-}"