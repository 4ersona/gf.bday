#!/usr/bin/env bash
# Builds dist/lumette-theme.zip with theme files at the ZIP ROOT (what Shopify requires).
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'PY'
import json, glob, sys
bad = 0
for f in glob.glob('theme/**/*.json', recursive=True):
    try: json.load(open(f))
    except Exception as e: print('Invalid JSON', f, e); bad += 1
sys.exit(1 if bad else 0)
PY
mkdir -p dist && rm -f dist/lumette-theme.zip
(cd theme && zip -r -X -D ../dist/lumette-theme.zip assets config layout locales sections snippets templates -x '*.DS_Store')
echo "Built dist/lumette-theme.zip"; unzip -l dist/lumette-theme.zip | tail -1
