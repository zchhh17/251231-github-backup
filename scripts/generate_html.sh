#!/usr/bin/env bash
set -Eeuo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="$BASE_DIR/work/backup-repo"

INDEX_JSON="$BACKUP_DIR/index.json"
INDEX_HTML="$BACKUP_DIR/index.html"

[[ -f "$INDEX_JSON" ]] || {
  echo "❌ index.json 不存在"
  exit 1
}

echo "🖼 生成 index.html ..."

TOTAL="$(jq '.total' "$INDEX_JSON")"
GENERATED_AT="$(jq -r '.generated_at' "$INDEX_JSON")"

cat > "$INDEX_HTML" <<'HTML'
<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<title>GitHub 备份索引</title>
<style>
body {
  font-family: system-ui, -apple-system, BlinkMacSystemFont;
  margin: 40px;
  background: #f6f8fa;
}
h1 { margin-bottom: 0.2em; }
.meta { color: #666; margin-bottom: 1.5em; }
.card {
  background: #fff;
  border-radius: 8px;
  padding: 16px;
  margin-bottom: 16px;
  box-shadow: 0 2px 6px rgba(0,0,0,0.05);
}
.repo { font-weight: bold; font-size: 1.1em; }
.small { color: #555; font-size: 0.9em; }
code {
  background: #eee;
  padding: 2px 6px;
  border-radius: 4px;
}
</style>
</head>
<body>

<h1>📦 GitHub 备份索引</h1>
<div class="meta">
  生成时间：<span id="gen"></span><br>
  总备份数：<span id="total"></span>
</div>

<div id="list"></div>

<script>
const data =
HTML

jq '.items' "$INDEX_JSON" >> "$INDEX_HTML"

cat >> "$INDEX_HTML" <<'HTML'
;

document.getElementById('gen').textContent = data.generated_at || '';
document.getElementById('total').textContent = data.length || 0;

const list = document.getElementById('list');

data.forEach(item => {
  const div = document.createElement('div');
  div.className = 'card';
  div.innerHTML = `
    <div class="repo">${item.repo}</div>
    <div class="small">时间：${item.timestamp}</div>
    <div class="small">包：<code>${item.package}</code></div>
    <div class="small">SHA256：<code>${item.sha256}</code></div>
    <div class="small">大小：${(item.size_bytes / 1024 / 1024).toFixed(2)} MB</div>
  `;
  list.appendChild(div);
});
</script>

</body>
</html>
HTML

cd "$BACKUP_DIR"
git add index.html
git commit -m "chore: update index.html"
git push

echo "✅ index.html 已生成并提交"
