#!/usr/bin/env bash
set -Eeuo pipefail

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
REPOS_FILE="$BASE_DIR/repos.txt"
WORK_ROOT="$BASE_DIR/work"
ARCHIVE_ROOT="$BASE_DIR/archives"

INDEX_JSON="$BASE_DIR/index.json"
INDEX_HTML="$BASE_DIR/index.html"

# ===== Actions Git 身份 =====
if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
  git config --global user.name "github-actions[bot]"
  git config --global user.email "github-actions[bot]@users.noreply.github.com"
  git remote set-url origin \
    "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"
fi

SUCCESS=()
FAILED=()

while read -r repo; do
  [[ -z "$repo" || "$repo" =~ ^# ]] && continue

  if ./backup_one.sh "$repo"; then
    SUCCESS+=("$repo")
  else
    FAILED+=("$repo")
  fi
done < "$REPOS_FILE"

# ===== 生成 index.json =====
jq -s '{
  generated_at: now | strftime("%Y-%m-%d %H:%M:%S"),
  items: .
}' "$WORK_ROOT"/*/*/report.json > "$INDEX_JSON"

# ===== 生成 index.html =====
cat > "$INDEX_HTML" <<'EOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<title>GitHub Backup Index</title>
<style>
body{font-family:sans-serif;margin:40px;}
table{border-collapse:collapse;width:100%;}
th,td{border:1px solid #ccc;padding:8px;}
th{background:#f5f5f5;}
</style>
</head>
<body>
<h1>📦 GitHub 多仓备份索引</h1>
<p>生成时间：<span id="t"></span></p>
<table>
<thead>
<tr>
<th>仓库</th>
<th>时间</th>
<th>文件</th>
<th>SHA256</th>
</tr>
</thead>
<tbody id="data"></tbody>
</table>

<script>
fetch('index.json')
.then(r=>r.json())
.then(j=>{
  document.getElementById('t').textContent=j.generated_at;
  const tb=document.getElementById('data');
  j.items.forEach(i=>{
    const tr=document.createElement('tr');
    tr.innerHTML=`
      <td>${i.repo}</td>
      <td>${i.timestamp}</td>
      <td>${i.package}</td>
      <td><code>${i.sha256}</code></td>`;
    tb.appendChild(tr);
  });
});
</script>
</body>
</html>
EOF

# ===== 入库 =====
git add archives index.json index.html
git commit -m "backup(all): $(date '+%Y%m%d-%H%M%S')" || true
git push

# ===== 清理 7 天前 work =====
find "$WORK_ROOT" -mindepth 2 -maxdepth 2 -type d -mtime +7 -exec rm -rf {} +

echo
echo "✅ 成功仓库：${#SUCCESS[@]}"
printf '  ✔ %s\n' "${SUCCESS[@]:-}"

echo
echo "❌ 失败仓库：${#FAILED[@]}"
printf '  ✘ %s\n' "${FAILED[@]:-}"
