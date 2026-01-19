#!/usr/bin/env bash
set -euo pipefail

INDEX_JSON="index.json"
OUT_DIR="public"

mkdir -p "$OUT_DIR"

# ---------- 基础 CSS ----------
mkdir -p "$OUT_DIR/assets"
cat > "$OUT_DIR/assets/style.css" <<'EOF'
body { font-family: system-ui, sans-serif; max-width: 960px; margin: auto; padding: 2em; }
h1, h2 { border-bottom: 1px solid #ddd; padding-bottom: .3em; }
table { width: 100%; border-collapse: collapse; }
th, td { padding: .5em; border-bottom: 1px solid #eee; text-align: left; }
small { color: #666; }
a { color: #0366d6; text-decoration: none; }
a:hover { text-decoration: underline; }
EOF

# ---------- 总览页 ----------
cat > "$OUT_DIR/index.html" <<EOF
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>GitHub Backup Index</title>
<link rel="stylesheet" href="assets/style.css">
</head>
<body>
<h1>📦 GitHub 备份索引</h1>
<table>
<tr>
<th>Author</th>
<th>Repo</th>
<th>Latest Backup</th>
<th>Status</th>
</tr>
EOF

jq -r '
  .[]
  | select(.status=="success")
  | "\(.owner) \(.repo) \(.timestamp)"
' "$INDEX_JSON" | sort -u | while read -r owner repo ts; do
  mkdir -p "$OUT_DIR/$owner"

  echo "<tr>" >> "$OUT_DIR/index.html"
  echo "<td>$owner</td>" >> "$OUT_DIR/index.html"
  echo "<td><a href=\"$owner/$repo.html\">$repo</a></td>" >> "$OUT_DIR/index.html"
  echo "<td><small>$ts</small></td>" >> "$OUT_DIR/index.html"
  echo "<td>✅</td>" >> "$OUT_DIR/index.html"
  echo "</tr>" >> "$OUT_DIR/index.html"
done

cat >> "$OUT_DIR/index.html" <<EOF
</table>
</body>
</html>
EOF

# ---------- 单仓页面 ----------
jq -r '
  .[]
  | select(.status=="success")
  | "\(.owner) \(.repo)"
' "$INDEX_JSON" | sort -u | while read -r owner repo; do

  OUT_FILE="$OUT_DIR/$owner/$repo.html"

  cat > "$OUT_FILE" <<EOF
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>$owner / $repo</title>
<link rel="stylesheet" href="../assets/style.css">
</head>
<body>

<h1>$owner / $repo</h1>
<p><a href="../index.html">← 返回索引</a></p>

<table>
<tr>
<th>Time</th>
<th>Package</th>
<th>SHA256</th>
<th>Size</th>
</tr>
EOF

  jq -r --arg o "$owner" --arg r "$repo" '
    .[]
    | select(.owner==$o and .repo==$r and .status=="success")
    | "<tr><td>\(.timestamp)</td><td>\(.package)</td><td><small>\(.sha256)</small></td><td>\(.size_bytes)</td></tr>"
  ' "$INDEX_JSON" >> "$OUT_FILE"

  cat >> "$OUT_FILE" <<EOF
</table>
</body>
</html>
EOF

done

echo "✅ HTML 页面生成完成：$OUT_DIR/"
