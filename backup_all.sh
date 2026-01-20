#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_ROOT="$ROOT_DIR/work"
PUBLIC_DIR="$ROOT_DIR/public"
REPOS_FILE="$ROOT_DIR/repos.txt"

mkdir -p "$WORK_ROOT" "$PUBLIC_DIR"

SUCCESS=()
FAILED=()

while read -r repo; do
  [[ -z "$repo" || "$repo" =~ ^# ]] && continue

  if ./backup_one.sh "$repo"; then
    SUCCESS+=("$repo")
  else
    FAILED+=("$repo")
  fi

  echo "----------------------------"
done < "$REPOS_FILE"

# ===== index.json 聚合 =====
INDEX_JSON="$PUBLIC_DIR/index.json"
jq -s '.' work/*/*/report.json > index.json


# ===== HTML 页面 =====
cat > "$PUBLIC_DIR/index.html" <<'EOF'
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>GitHub Backup Index</title>
</head>
<body>
<h1>GitHub Backup Index</h1>
<ul id="list"></ul>
<script>
fetch('index.json').then(r=>r.json()).then(data=>{
  const ul = document.getElementById('list');
  data.forEach(i=>{
    const li=document.createElement('li');
    li.innerText = `${i.repo} | ${i.status} | ${i.timestamp}`;
    ul.appendChild(li);
  });
});
</script>
</body>
</html>
EOF

# ===== Actions push 处理 =====
if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
  git config user.name "github-actions[bot]"
  git config user.email "github-actions[bot]@users.noreply.github.com"
  git remote set-url origin \
    "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"
fi

git add public
git commit -m "update index $(date '+%Y%m%d-%H%M%S')" || true
git push

echo "✅ 成功仓库：${#SUCCESS[@]}"
printf '  ✔ %s\n' "${SUCCESS[@]:-}"

echo
echo "❌ 失败仓库：${#FAILED[@]}"
printf '  ✘ %s\n' "${FAILED[@]:-}"

[[ ${#FAILED[@]} -eq 0 ]]