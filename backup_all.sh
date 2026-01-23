#!/usr/bin/env bash
set -Eeuo pipefail

: "${GITHUB_TOKEN:=}"

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_ROOT="$BASE_DIR/work"
ARCHIVE_ROOT="$BASE_DIR/archives"
REPOS_FILE="$BASE_DIR/repos.txt"
INDEX_JSON="$BASE_DIR/index.json"

mkdir -p "$ARCHIVE_ROOT"

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
    continue
  fi

  KEY="$(basename "$(dirname "$repo")")__$(basename "$repo" .git)"
  LATEST="$(ls -1 "$WORK_ROOT/$KEY" | sort | tail -n1)"
  SRC="$WORK_ROOT/$KEY/$LATEST"

  mkdir -p "$ARCHIVE_ROOT/$KEY/snapshots" "$ARCHIVE_ROOT/$KEY/updates"

  cp "$SRC/_pkg/"*.tar.gz "$ARCHIVE_ROOT/$KEY/snapshots/"
  cp "$SRC/update.md" "$ARCHIVE_ROOT/$KEY/updates/$LATEST.md"
done < "$REPOS_FILE"

# ===== index.json =====
jq -s '{
  generated_at: now | strftime("%Y-%m-%d %H:%M:%S"),
  items: .
}' "$WORK_ROOT"/*/*/report.json > "$INDEX_JSON"

git add archives index.json
git commit -m "backup(all): $(date '+%Y%m%d-%H%M%S')" || true
git push

TAG="backup-$(date '+%Y%m%d-%H%M%S')"
git tag "$TAG"
git push origin "$TAG"

# ===== 清理 7 天前 work =====
find "$WORK_ROOT" -mindepth 2 -maxdepth 2 -type d -mtime +7 -exec rm -rf {} +

echo
echo "✅ 成功仓库：${#SUCCESS[@]}"
printf '  ✔ %s\n' "${SUCCESS[@]:-}"

echo
echo "❌ 失败仓库：${#FAILED[@]}"
printf '  ✘ %s\n' "${FAILED[@]:-}"

# ===== index.json（聚合生成）=====
echo "🧩 生成 index.json"

INDEX_JSON="public/index.json"
mkdir -p public

jq -n '{
  generated_at: (now | strftime("%Y-%m-%d %H:%M:%S")),
  items: []
}' > "$INDEX_JSON"

for r in archives/*; do
  [ -d "$r" ] || continue
  repo="$(basename "$r")"

  last_pkg="$(ls -1 "$r/snapshots"/*.tar.gz 2>/dev/null | sort | tail -n1)"
  [ -f "$last_pkg" ] || continue

  ts="$(basename "$last_pkg" | sed -E 's/.*-([0-9]{8}-[0-9]{6}).*/\1/')"
  size="$(stat -c '%s' "$last_pkg")"
  sha="$(sha256sum "$last_pkg" | awk '{print $1}')"

  jq --arg repo "$repo" \
     --arg ts "$ts" \
     --arg file "$(basename "$last_pkg")" \
     --arg sha "$sha" \
     --arg size "$size" \
     '.items += [{
        repo: $repo,
        timestamp: $ts,
        file: $file,
        sha256: $sha,
        size_bytes: ($size | tonumber)
     }]' "$INDEX_JSON" > "$INDEX_JSON.tmp" \
     && mv "$INDEX_JSON.tmp" "$INDEX_JSON"
done

# ===== index.html（静态页面） =====
echo "🌐 生成 index.html"

cat > public/index.html <<'EOF'
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
<table>
<thead>
<tr>
<th>仓库</th>
<th>时间</th>
<th>文件</th>
<th>大小</th>
<th>SHA256</th>
</tr>
</thead>
<tbody id="data"></tbody>
</table>

<script>
fetch('index.json')
.then(r=>r.json())
.then(j=>{
  const tb=document.getElementById('data');
  j.items.forEach(i=>{
    const tr=document.createElement('tr');
    tr.innerHTML=`
      <td>${i.repo}</td>
      <td>${i.timestamp}</td>
      <td>${i.file}</td>
      <td>${(i.size_bytes/1024/1024).toFixed(2)} MB</td>
      <td><code>${i.sha256}</code></td>`;
    tb.appendChild(tr);
  });
});
</script>
</body>
</html>
EOF

# ===== GitHub Release（④） =====
echo "🚀 创建 GitHub Release"

TAG="backup-$(date '+%Y%m%d-%H%M%S')"

gh release create "$TAG" \
  public/index.json \
  public/index.html \
  --title "Backup $TAG" \
  --notes "自动多仓备份 Release"
