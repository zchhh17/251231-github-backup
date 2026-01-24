#!/usr/bin/env bash
set -Eeuo pipefail

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
REPOS_FILE="$BASE_DIR/repos.txt"
ARCHIVE_ROOT="$BASE_DIR/archives"

# ===== Actions Git 身份 =====
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
done < "$REPOS_FILE"

# ===== 入库（只提交 archives）=====
git add "$ARCHIVE_ROOT"
git commit -m "backup(all): $(date '+%Y%m%d-%H%M%S')" || true
git push

echo
echo "✅ 成功仓库：${#SUCCESS[@]}"
printf '  ✔ %s\n' "${SUCCESS[@]:-}"

echo
echo "❌ 失败仓库：${#FAILED[@]}"
printf '  ✘ %s\n' "${FAILED[@]:-}"
