#!/usr/bin/env bash
set -euo pipefail

REPO_URL="$1"
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_ROOT="$ROOT_DIR/work"

REPO_PATH="${REPO_URL##*github.com/}"
REPO_PATH="${REPO_PATH%.git}"
OWNER="${REPO_PATH%%/*}"
NAME="${REPO_PATH##*/}"
SAFE_NAME="${OWNER}__${NAME}"

TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
BASE_DIR="$WORK_ROOT/$SAFE_NAME/$TIMESTAMP"
SRC_DIR="$BASE_DIR/src"
PKG_DIR="$BASE_DIR/pkg"

mkdir -p "$SRC_DIR" "$PKG_DIR"

echo "➡️ 处理仓库：$SAFE_NAME"

git clone --depth=1 "$REPO_URL" "$SRC_DIR"

PKG_FILE="$PKG_DIR/source-${SAFE_NAME}-${TIMESTAMP}.tar.gz"
tar --exclude='.git' -czf "$PKG_FILE" -C "$SRC_DIR" .

SHA256="$(sha256sum "$PKG_FILE" | awk '{print $1}')"
SIZE="$(stat -c '%s' "$PKG_FILE')"

cat > "$BASE_DIR/report.json" <<EOF
{
  "repo": "$SAFE_NAME",
  "repo_url": "$REPO_URL",
  "timestamp": "$TIMESTAMP",
  "status": "success",
  "package": "$(basename "$PKG_FILE")",
  "sha256": "$SHA256",
  "size_bytes": $SIZE
}
EOF