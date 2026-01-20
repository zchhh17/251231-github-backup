#!/usr/bin/env bash
set -Eeuo pipefail

REPO_URL="${1:?repo url required}"

AUTHOR="$(basename "$(dirname "$REPO_URL")")"
PROJECT="$(basename "$REPO_URL" .git)"
REPO_KEY="${AUTHOR}__${PROJECT}"

TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_ROOT="$BASE_DIR/work"
WORK_DIR="$WORK_ROOT/$REPO_KEY/$TIMESTAMP"
SRC_DIR="$WORK_DIR/src"
PKG_DIR="$WORK_DIR/_pkg"

mkdir -p "$SRC_DIR" "$PKG_DIR"

echo "➡️ 处理仓库：$REPO_KEY"

git clone --depth=1 "$REPO_URL" "$SRC_DIR"

PKG_NAME="source-${REPO_KEY}-${TIMESTAMP}.tar.gz"
PKG_PATH="$PKG_DIR/$PKG_NAME"

tar \
  --exclude='.git' \
  --exclude='_pkg' \
  -czf "$PKG_PATH" \
  -C "$SRC_DIR" .

# ===== updates.md =====
UPDATE_MD="$WORK_DIR/update.md"
{
  echo "# $REPO_KEY"
  echo
  echo "- 备份时间：$TIMESTAMP"
  echo "- 来源仓库：$REPO_URL"
  echo
  echo "## 最近提交（10 条）"
  git -C "$SRC_DIR" log -10 --pretty=format:'- %h %s (%an)'
} > "$UPDATE_MD"

# ===== report.json =====
SHA256="$(sha256sum "$PKG_PATH" | awk '{print $1}')"
SIZE="$(stat -c '%s' "$PKG_PATH")"

cat > "$WORK_DIR/report.json" <<EOF
{
  "repo": "$REPO_KEY",
  "repo_url": "$REPO_URL",
  "timestamp": "$TIMESTAMP",
  "package": "$PKG_NAME",
  "sha256": "$SHA256",
  "size_bytes": $SIZE,
  "status": "success"
}
EOF

echo "✅ 完成：$REPO_KEY"