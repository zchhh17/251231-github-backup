#!/usr/bin/env bash
set -e

set -Eeuo pipefail

# ---- 输入解析 ----
REPO_URL="${1:-}"

if [[ -n "$REPO_URL" ]]; then
  REPO_NAME="$(basename "$REPO_URL" .git)"
fi

: "${REPO_NAME:?REPO_NAME is required}"

# ---- 时间戳兜底（关键）----
TIMESTAMP="${TIMESTAMP:-$(date '+%Y%m%d-%H%M%S')}"

# ---- Path Lock ----
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_ROOT="$BASE_DIR/work"
WORK_DIR="$WORK_ROOT/${REPO_NAME}-${TIMESTAMP}"
_PKG_DIR="$WORK_DIR/_pkg"
LOG_DIR="$BASE_DIR/logs"

mkdir -p "$WORK_ROOT" "$WORK_DIR" "$_PKG_DIR" "$LOG_DIR"

for p in "$WORK_ROOT" "$WORK_DIR" "$_PKG_DIR"; do
  [[ "$p" == "/" || -z "$p" ]] && {
    echo "❌ 非法路径 [$p]"
    exit 99
  }
done

# ===== Path Lock END =====

# ========== 基本参数 ==========
repo="$1"
[[ -z "$repo" ]] && {
  echo "❌ 未提供仓库地址"
  exit 1
}

# ========== 载入配置 ==========
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/2601010724config.conf"

# ========== 变量 ==========
name="$(basename "$repo" .git)"
ts="$(date +"$TIME_FMT")"

tmp="$WORK_DIR/$name-$ts"
dst="$WORK_DIR/backup-repo"

PKG_NAME="source-$name-$ts.tar.gz"
PKG_PATH="$WORK_DIR/$PKG_NAME"

echo "➡️ 处理仓库：$name"

# ========== clone 源仓库 ==========
"$GIT_BIN" clone --depth=1 "$repo" "$tmp"

# ========== 准备打包目录 ==========
mkdir -p "$tmp/_pkg"

# ========== B 方案打包（不自引用） ==========
tar \
  --exclude='_pkg' \
  --exclude='.git' \
  -czf "$PKG_PATH" \
  -C "$tmp" .

mv "$PKG_PATH" "$tmp/_pkg/"

# ========== 校验打包结果 ==========
[[ -f "$tmp/_pkg/$PKG_NAME" ]] || {
  echo "❌ 找不到打包文件：$PKG_NAME"
  exit 1
}

# ========== 准备集中备份仓库 ==========
if [[ ! -d "$dst/.git" ]]; then
  "$GIT_BIN" clone "$BACKUP_REPO" "$dst"
fi

cd "$dst"

mkdir -p "$name/snapshots" "$name/updates"

# ========== 复制源码包 ==========
cp "$tmp/_pkg/$PKG_NAME" "$name/snapshots/"

# ========== 生成 diff + commit log 摘要 ==========
UPDATE_MD="$name/updates/$ts.md"

{
  echo "# $name"
  echo
  echo "- 备份时间：$ts"
  echo "- 来源仓库：$repo"
  echo
  echo "## 最近提交记录（最新 10 条）"
  echo
  git -C "$tmp" log -10 --pretty=format:'- %h %s (%an)'
  echo
  echo
  echo "## 最近代码变更统计（HEAD）"
  echo
  git -C "$tmp" show --stat --oneline HEAD
} > "$UPDATE_MD"

# ========== 提交到集中仓库 ==========
"$GIT_BIN" add "$name"
"$GIT_BIN" commit -m "backup($name): $ts"
"$GIT_BIN" push

# ========== 创建 tag / release ==========
tag="$name-$ts"
"$GIT_BIN" tag "$tag"
"$GIT_BIN" push origin "$tag"

echo "🔗 Release:"
echo "https://github.com/$(basename "$BACKUP_REPO" .git)/releases/tag/$tag"

# ========== 清理临时目录 ==========
rm -rf "$tmp"

echo "✅ 完成：$name"

# ========== report.json ==========
REPORT_FILE="$tmp/_pkg/report.json"

timestamp_human="$(date '+%Y-%m-%d %H:%M:%S')"

if [[ -f "$PKG_FILE" ]]; then
  sha256="$(sha256sum "$PKG_FILE" | awk '{print $1}')"
  size="$(stat -c '%s' "$PKG_FILE")"

  cat > "$REPORT_FILE" <<EOF
{
  "repo": "$name",
  "repo_url": "$repo",
  "timestamp": "$timestamp_human",
  "status": "success",
  "workdir": "$(basename "$WORK_DIR")",
  "package": "$(basename "$PKG_FILE")",
  "sha256": "$sha256",
  "size_bytes": $size
}
EOF
else
  cat > "$REPORT_FILE" <<EOF
{
  "repo": "$name",
  "repo_url": "$repo",
  "timestamp": "$timestamp_human",
  "status": "failed",
  "error": "package not found"
}
EOF
fi
