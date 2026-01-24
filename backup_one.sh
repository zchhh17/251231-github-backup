#!/usr/bin/env bash
set -Eeuo pipefail

# ================= 基本输入 =================
REPO_URL="${1:-}"
[[ -z "$REPO_URL" ]] && { echo "❌ 未提供仓库地址"; exit 1; }

OWNER="$(basename "$(dirname "$REPO_URL")")"
NAME="$(basename "$REPO_URL" .git)"
KEY="${OWNER}__${NAME}"

TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"

# ================= 路径锁定 =================
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_ROOT="$BASE_DIR/work"
ARCHIVE_ROOT="$BASE_DIR/archives"

WORK_DIR="$WORK_ROOT/$KEY/$TIMESTAMP"
SRC_DIR="$WORK_DIR/src"
PKG_DIR="$WORK_DIR/_pkg"

mkdir -p "$SRC_DIR" "$PKG_DIR" "$ARCHIVE_ROOT/$KEY/snapshots" "$ARCHIVE_ROOT/$KEY/updates"

# 防止灾难路径
for p in "$WORK_ROOT" "$ARCHIVE_ROOT" "$WORK_DIR"; do
  [[ "$p" == "/" || -z "$p" ]] && { echo "❌ 非法路径：$p"; exit 99; }
done

echo "➡️ 处理仓库：$KEY"

# ================= clone（强制干净） =================
git clone --depth=1 "$REPO_URL" "$SRC_DIR"

cd "$SRC_DIR"
HEAD_COMMIT="$(git rev-parse HEAD)"

# ================= A 方案：源码快照 =================
PKG_NAME="source-${KEY}-${TIMESTAMP}.tar.gz"
PKG_PATH="$PKG_DIR/$PKG_NAME"

tar \
  --exclude=.git \
  --exclude=_pkg \
  -czf "$PKG_PATH" \
  .

# ================= 是否变化判断 =================
LAST_PKG="$(ls -1 "$ARCHIVE_ROOT/$KEY/snapshots/"*.tar.gz 2>/dev/null | sort | tail -n1 || true)"

if [[ -n "$LAST_PKG" ]]; then
  if sha256sum "$LAST_PKG" "$PKG_PATH" | awk '{print $1}' | uniq | wc -l | grep -q '^1$'; then
    echo "ℹ️ 源码未变化，跳过归档"
    rm -rf "$WORK_DIR"
    exit 0
  fi
fi

# ================= 入 archives =================
cp "$PKG_PATH" "$ARCHIVE_ROOT/$KEY/snapshots/"

UPDATE_MD="$ARCHIVE_ROOT/$KEY/updates/${TIMESTAMP}.md"
{
  echo "# $KEY"
  echo
  echo "- 备份时间：$TIMESTAMP"
  echo "- 仓库：$REPO_URL"
  echo "- Commit：$HEAD_COMMIT"
  echo
  echo "## 最近提交（10 条）"
  git log -10 --pretty=format:'- %h %s (%an)'
  echo
  echo
  echo "## 最新提交变更"
  git show --stat --oneline HEAD
} > "$UPDATE_MD"

echo "✅ 新源码已归档：$KEY"

# ================= 清理 =================
rm -rf "$WORK_DIR"
