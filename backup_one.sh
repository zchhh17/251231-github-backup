#!/usr/bin/env bash
set -Eeuo pipefail

# ================= 基本参数 =================
REPO_URL="${1:-}"
if [[ -z "$REPO_URL" ]]; then
  echo "❌ 未提供仓库地址"
  exit 1
fi

# repo key：author__repo
AUTHOR="$(basename "$(dirname "$REPO_URL")")"
REPO_NAME="$(basename "$REPO_URL" .git)"
KEY="${AUTHOR}__${REPO_NAME}"

TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_ROOT="$BASE_DIR/work"
WORK_DIR="$WORK_ROOT/$KEY/$TIMESTAMP"
SRC_DIR="$WORK_DIR/src"
PKG_DIR="$WORK_DIR/_pkg"

mkdir -p "$SRC_DIR" "$PKG_DIR"

echo "➡️ 处理仓库：$KEY"

# ================= clone =================
git clone --depth=1 "$REPO_URL" "$SRC_DIR"

# ================= 打包（不包含 .git） =================
PKG_NAME="source-${KEY}-${TIMESTAMP}.tar.gz"
PKG_PATH="$PKG_DIR/$PKG_NAME"

tar \
  --exclude='.git' \
  -czf "$PKG_PATH" \
  -C "$SRC_DIR" .

if [[ ! -f "$PKG_PATH" ]]; then
  echo "❌ 打包失败"
  exit 2
fi

# ================= update.md =================
UPDATE_MD="$WORK_DIR/update.md"
{
  echo "# $KEY"
  echo
  echo "- 时间：$TIMESTAMP"
  echo "- 来源：$REPO_URL"
  echo
  echo "## 最近提交（10 条）"
  git -C "$SRC_DIR" log -10 --pretty=format:'- %h %s (%an)'
} > "$UPDATE_MD"

# ================= report.json =================
REPORT_JSON="$WORK_DIR/report.json"
SIZE_BYTES="$(stat -c '%s' "$PKG_PATH")"
SHA256="$(sha256sum "$PKG_PATH" | awk '{print $1}')"

cat > "$REPORT_JSON" <<EOF
{
  "repo": "$KEY",
  "repo_url": "$REPO_URL",
  "timestamp": "$TIMESTAMP",
  "package": "$PKG_NAME",
  "size_bytes": $SIZE_BYTES,
  "sha256": "$SHA256"
}
EOF

echo "✅ 完成：$KEY"
