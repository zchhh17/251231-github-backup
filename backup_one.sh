#!/usr/bin/env bash
set -Eeuo pipefail

REPO_URL="$1"
[[ -z "$REPO_URL" ]] && { echo "❌ 未提供仓库地址"; exit 1; }

OWNER="$(basename "$(dirname "$REPO_URL")")"
NAME="$(basename "$REPO_URL" .git)"
KEY="${OWNER}__${NAME}"

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_ROOT="$BASE_DIR/work"
ARCHIVE_ROOT="$BASE_DIR/archives"

TS="$(date '+%Y%m%d-%H%M%S')"
WORK_DIR="$WORK_ROOT/$KEY/$TS"
SRC_DIR="$WORK_DIR/src"
PKG_DIR="$WORK_DIR/_pkg"

mkdir -p "$SRC_DIR" "$PKG_DIR"

echo "➡️ 处理仓库：$KEY"

git clone --depth=1 "$REPO_URL" "$SRC_DIR"

PKG_NAME="source-${KEY}-${TS}.tar.gz"
PKG_PATH="$PKG_DIR/$PKG_NAME"

tar \
  --exclude='.git' \
  --exclude='_pkg' \
  -czf "$PKG_PATH" \
  -C "$SRC_DIR" .

# ===== 生成 update.md =====
git -C "$SRC_DIR" log -10 --pretty=format:'- %h %s (%an)' > "$WORK_DIR/update.md"

# ===== 生成 report.json =====
sha="$(sha256sum "$PKG_PATH" | awk '{print $1}')"
size="$(stat -c '%s' "$PKG_PATH')"

cat > "$WORK_DIR/report.json" <<EOF
{
  "repo": "$KEY",
  "repo_url": "$REPO_URL",
  "timestamp": "$(date '+%Y-%m-%d %H:%M:%S')",
  "status": "success",
  "package": "$PKG_NAME",
  "sha256": "$sha",
  "size_bytes": $size
}
EOF

# ===== 入库 =====
mkdir -p "$ARCHIVE_ROOT/$KEY/snapshots" "$ARCHIVE_ROOT/$KEY/updates"

cp "$PKG_PATH" "$ARCHIVE_ROOT/$KEY/snapshots/"
cp "$WORK_DIR/update.md" "$ARCHIVE_ROOT/$KEY/updates/$TS.md"

echo "✅ 完成：$KEY"
