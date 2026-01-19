#!/usr/bin/env bash
set -euo pipefail

# ====== 配置区 ======
BACKUP_REPO="zchhh17/251231-github-backup"
TAG="index-latest"
ASSET="index.json"
TITLE="📦 Backup Index (Latest)"
NOTE="Auto-updated index.json"
# ===================

[[ -f "$ASSET" ]] || {
  echo "❌ 找不到 $ASSET"
  exit 1
}

# 确保在备份仓库
git remote get-url origin | grep -q "$BACKUP_REPO" || {
  echo "❌ 当前仓库不是 $BACKUP_REPO"
  exit 2
}

echo "➡️ 准备发布 index.json 到 Release [$TAG]"

# ---------- 创建或更新 Release ----------
if gh release view "$TAG" >/dev/null 2>&1; then
  echo "🔁 Release 已存在，更新 asset"
  gh release upload "$TAG" "$ASSET" --clobber
else
  echo "🆕 创建新 Release"
  gh release create "$TAG" "$ASSET" \
    --title "$TITLE" \
    --notes "$NOTE"
fi

echo "✅ index.json 已上传到 Release："
echo "https://github.com/$BACKUP_REPO/releases/tag/$TAG"
