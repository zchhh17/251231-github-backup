#!/usr/bin/env bash
set -Eeuo pipefail

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$BASE_DIR/logs"
LOG_FILE="$LOG_DIR/backup_all-$(date '+%Y%m%d-%H%M%S').log"

mkdir -p "$LOG_DIR"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "🚀 GitHub Backup 全流程开始"
echo "🕒 $(date '+%F %T')"
echo "======================================"

step () {
  echo
  echo "▶️ $1"
  echo "--------------------------------------"
}

# 1. 多仓备份
step "多仓备份（B 方案）"
bash "$BASE_DIR/2601031022backup_all_B.sh"

# 2. 构建 index.json
step "生成 index.json"
bash "$BASE_DIR/2601031022build_index.sh"

# 3. 构建 HTML 索引
step "生成 index.html"
bash "$BASE_DIR/generate_index_html.sh"

# 4. 发布 index.json 到 Release
step "发布 index.json 到 GitHub Release"
bash "$BASE_DIR/2601031036publish_index.sh"

# 5. index.html → GitHub Pages 自动发布（终版）
step "发布 index.html 到 GitHub Pages"
bash "$BASE_DIR/2601032021publish_pages.sh"

# 6. 清理旧 work 目录（默认 10 天）
step "清理旧 work 目录"
bash "$BASE_DIR/cleanup_work.sh 10"

echo
echo "======================================"
echo "🎉 全流程完成"
echo "📄 日志：$LOG_FILE"
