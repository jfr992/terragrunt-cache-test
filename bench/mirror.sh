#!/usr/bin/env bash
# One-time (network) step: build the local filesystem provider mirror used by all offline suites.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; TOFU="${TOFU:-tofu}"; OUT="$ROOT/work/mirror"
tmp="$(mktemp -d)"
python3 -c "import sys; sys.path.insert(0,'$ROOT/bench'); import gen; open('$tmp/main.tf','w').write(gen.MODULES['cache'].split('variable')[0])"
"$TOFU" -chdir="$tmp" providers mirror -platform=linux_amd64 -platform=linux_arm64 \
  -platform=darwin_amd64 -platform=darwin_arm64 "$OUT"
rm -rf "$tmp"; echo "mirror at $OUT"
