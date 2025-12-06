#!/usr/bin/env bash
set -euo pipefail

dir="${1:-build/web}"
budget_mb="${2:-30}"

if [[ ! -d "$dir" ]]; then
  echo "Directory not found: $dir"
  exit 1
fi

bytes=$(find "$dir" -type f \( -name "*.wasm" -o -name "*.pck" \) -print0 | xargs -0 cat | wc -c | awk '{print $1}')
mb=$(python3 - <<PY
print(${bytes} / (1024*1024))
PY
)

echo "Size of wasm+pck in '$dir': ${mb} MB (budget ${budget_mb} MB)"

python3 - <<PY
import sys
mb = float("${mb}")
budget = float("${budget_mb}")
sys.exit(0 if mb <= budget else 1)
PY



