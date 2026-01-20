#!/usr/bin/env bash
set -Eeuo pipefail

# ================== 基本输入 ==================
REPO_URL="${1:-}"
: "${REPO_URL:?❌ 未提供仓库地址}"
: "${REPO_NAME:?❌ REPO_NAME is required (由 backup_all.sh 传入)}"

TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"

# ================== Path Lock ==================
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_ROOT="$BASE_DIR/work"
LOG_DIR="$BASE_DIR/logs"

WORK_DIR="$WORK_ROOT/$REPO_NAME/$TIMESTAMP"
SRC_DIR="$WORK_DIR/src"
PKG_DIR="$WORK_DIR/_pkg"

mkdir -p "$SRC_DIR" "$PKG_DIR" "$LOG_DIR"

for p in "$WORK_ROOT" "$WORK_DIR" "$SRC_DIR" "$PKG_DIR"; do
  [[ "$p" == "/" || -z "$p" ]] && {
    echo "❌ 非法路径：$p"
    exit 99
  }
done

# ================== 加载配置 ==================
source "$BASE_DIR/2601010724config.conf"

# ================== 变量 ==================
REPO_SHORT="$(basename "$REPO_URL" .git)"
PKG_NAME="source-${REPO_NAME}-${TIMESTAMP}.tar.gz"
PKG_FILE="$PKG_DIR/$PKG_NAME"
REPORT_FILE="$PKG_DIR/report.json"

echo "➡️ 处理仓库：$REPO_NAME"

# ================== clone ==================
"$GIT_BIN" clone --depth=1 "$REPO_URL" "$SRC_DIR"

# ================== B 方案打包（不自引用） ==================
tar \
  --exclude='.git' \
  --exclude='_pkg' \
  -czf "$PKG_FILE" \
  -C "$SRC_DIR" .

[[ -f "$PKG_FILE" ]] || {
  echo "❌ 打包失败：$PKG_FILE 不存在"
  exit 1
}

# ================== 准备集中备份仓库 ==================
BACKUP_DIR="$WORK_ROOT/backup-repo"

if [[ ! -d "$BACKUP_DIR/.git" ]]; then
  "$GIT_BIN" clone "$BACKUP_REPO" "$BACKUP_DIR"
fi

cd "$BACKUP_DIR"

mkdir -p "$REPO_NAME/snapshots" "$REPO_NAME/updates"

# ================== 复制源码包 ==================
cp "$PKG_FILE" "$REPO_NAME/snapshots/"

# ================== diff + commit log ==================
UPDATE_MD="$REPO_NAME/updates/$TIMESTAMP.md"

{
  echo "# $REPO_NAME"
  echo
  echo "- 备份时间：$TIMESTAMP"
  echo "- 来源仓库：$REPO_URL"
  echo
  echo "## 最近提交（10 条）"
  git -C "$SRC_DIR" log -10 --pretty=format:'- %h %s (%an)'
  echo
  echo
  echo "## HEAD 变更统计"
  git -C "$SRC_DIR" show --stat --oneline HEAD
} > "$UPDATE_MD"

# ================== 提交 / push ==================
"$GIT_BIN" add "$REPO_NAME"
"$GIT_BIN" commit -m "backup($REPO_NAME): $TIMESTAMP"
"$GIT_BIN" push

# ================== tag / release ==================
TAG="$REPO_NAME-$TIMESTAMP"
"$GIT_BIN" tag "$TAG"
"$GIT_BIN" push origin "$TAG"

echo "🔗 Release:"
echo "https://github.com/$(basename "$BACKUP_REPO" .git)/releases/tag/$TAG"

# ================== report.json ==================
SHA256="$(sha256sum "$PKG_FILE" | awk '{print $1}')"
SIZE_BYTES="$(stat -c '%s' "$PKG_FILE")"

cat > "$REPORT_FILE" <<EOF
{
  "repo": "$REPO_NAME",
  "repo_url": "$REPO_URL",
  "timestamp": "$TIMESTAMP",
  "status": "success",
  "package": "$(basename "$PKG_FILE")",
  "sha256": "$SHA256",
  "size_bytes": $SIZE_BYTES
}
EOF

# ================== 清理 ==================
rm -rf "$SRC_DIR"

echo "✅ 完成：$REPO_NAME"
