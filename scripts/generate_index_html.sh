#!/usr/bin/env bash
set -Eeuo pipefail

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
INDEX_JSON="$BASE_DIR/index.json"
OUTPUT="$BASE_DIR/index.html"

[[ -f "$INDEX_JSON" ]] || {
  echo "❌ index.json 不存在"
  exit 1
}

cat > "$OUTPUT" <<'EOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<title>GitHub Backup Index</title>
<style>
body { font-family: sans-serif; padding: 20px; }
table { border-collapse: collapse; width: 100%; }
th, td { border: 1px solid #ccc; padding: 6px 10px; }
th { background: #f5f5f5; }
.ok { color: #0a0; font-weight: bold; }
.fail { color: #c00; font-weight: bold; }
code { font-size: 12px; }
</style>
</head>
<body>

<h1>📦 GitHub Backup Index</h1>
<p>更新时间：<strong>EOF
EOF

date '+%Y-%m-%d %H:%M:%S' >> "$OUTPUT"

cat >> "$OUTPUT" <<'EOF'
</strong></p>

<table>
<tr>
  <th>Repository</th>
  <th>Time</th>
  <th>Status</th>
  <th>Package</th>
  <th>SHA256</th>
</tr>
EOF

# 逐条解析（不用 jq，兼容 Termux）
grep -n '"repo_id"' "$INDEX_JSON" | while read -r line; do
  n="${line%%:*}"

  repo_id=$(sed -n "${n}p" "$INDEX_JSON" | sed -n 's/.*"repo_id": "\(.*\)",/\1/p')
  repo=$(sed -n "$((n-2))p" "$INDEX_JSON" | sed -n 's/.*"repo": "\(.*\)",/\1/p')
  owner=$(sed -n "$((n-3))p" "$INDEX_JSON" | sed -n 's/.*"owner": "\(.*\)",/\1/p')
  status=$(sed -n "$((n+2))p" "$INDEX_JSON" | sed -n 's/.*"status": "\(.*\)",/\1/p')
  ts=$(sed -n "$((n+1))p" "$INDEX_JSON" | sed -n 's/.*"timestamp": "\(.*\)",/\1/p')
  pkg=$(sed -n "$((n+4))p" "$INDEX_JSON" | sed -n 's/.*"package": "\(.*\)",/\1/p')
  repo_url="https://github.com/${owner}/${repo}"
  dl_url="${repo_url}/releases/latest/download/${pkg}"
  sha=$(sed -n "$((n+5))p" "$INDEX_JSON" | sed -n 's/.*"sha256": "\(.*\)",/\1/p')

  cls="ok"
  [[ "$status" != "success" ]] && cls="fail"

  cat >> "$OUTPUT" <<EOF
<tr>
  <td><strong>${owner}/${repo}</strong><br><code>${repo_id}</code></td>
  <td>${ts}</td>
  <td class="${cls}">${status}</td>
  if [[ "$status" == "success" && -n "$pkg" ]]; then
    pkg_html="<a href=\"$dl_url\">$pkg</a>"
  else
    pkg_html="$pkg"
  fi
  <td>${pkg_html}</td>
  <td><code>${sha}</code></td>
</tr>
EOF
done

cat >> "$OUTPUT" <<'EOF'
</table>

</body>
</html>
EOF

echo "🌐 index.html 已生成：$OUTPUT"
