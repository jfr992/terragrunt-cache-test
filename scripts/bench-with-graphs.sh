#!/usr/bin/env bash
set -euo pipefail

ACTION="${ACTION:-plan}"
REPS="${REPS:-3}"
VERBOSE="${VERBOSE:-1}"  # Set to 0 to hide Terragrunt output
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

docker compose up -d minio minio-setup boring-registry worker >/dev/null
if [ ! -f "$ROOT/fixture-explicit/terragrunt.stack.hcl" ]; then
  bash "$ROOT/scripts/init-explicit-fixture.sh"
fi

if [ ! -f "$ROOT/fixture-implicit/eks/terragrunt.hcl" ]; then
  bash "$ROOT/scripts/init-implicit-fixture.sh"
fi

run_in_worker() {
  docker compose exec -T worker sh -lc "$*"
}

clear_caches() {
  echo "Clearing caches..."
  # Clear Layer 1 (Terragrunt Provider Cache - host filesystem)
  rm -rf "$ROOT/.cache/tofu-providers"/* "$ROOT/.cache/tg-modules"/* 2>/dev/null || true

  # Clear Layer 2 (MinIO - host volume)
  # Much faster than using mc commands, and avoids connection issues
  rm -rf "$ROOT/.data/minio/tofu-mirror"/* 2>/dev/null || true

  echo "Caches cleared (Layer 1 + Layer 2)"
}

prepare_cmd='rm -rf /workspace/.cache/tofu-providers/* /workspace/.cache/tg-modules/* 2>/dev/null || true'

echo "=== Terragrunt Cache Benchmark: Cold vs Warm Cache ==="
echo "Scenarios:"
echo "  1. Explicit Stack (no cache)"
echo "  2. Explicit Stack (with cache)"
echo "  3. Implicit Stack (no cache)"
echo "  4. Implicit Stack (with cache)"
echo ""

# Commands for the 4 scenarios
explicit_cold='cd /workspace/fixture-explicit && terragrunt stack run '"${ACTION}"' --parallelism 4 -no-color'
explicit_warm='cd /workspace/fixture-explicit && terragrunt stack run '"${ACTION}"' --parallelism 4 -no-color'
implicit_cold='cd /workspace/fixture-implicit && (export TG_PARALLELISM=4 && terragrunt run-all '"${ACTION}"' -no-color)'
implicit_warm='cd /workspace/fixture-implicit && (export TG_PARALLELISM=4 && terragrunt run-all '"${ACTION}"' -no-color)'

echo "Step 1: Clear all caches for initial state..."
clear_caches

echo ""
echo "Step 2: Run cold cache benchmarks (cache cleared before each run)..."

# Build hyperfine command with optional --show-output flag
show_output_flag=""
if [ "$VERBOSE" = "1" ]; then
  echo "  (Showing Terragrunt output for each run)"
  show_output_flag="--show-output"
else
  echo "  (Set VERBOSE=1 to see Terragrunt output)"
fi

run_in_worker "hyperfine \
  --runs ${REPS} \
  --prepare '${prepare_cmd}' \
  --ignore-failure \
  ${show_output_flag} \
  --export-json /workspace/bench-cold.json \
  --export-markdown /workspace/bench-cold.md \
  --command-name 'Explicit (cold cache)' \"${explicit_cold}\" \
  --command-name 'Implicit (cold cache)' \"${implicit_cold}\""

echo ""
echo "Step 3: Warm up caches by running each command once..."
run_in_worker "${explicit_warm}" >/dev/null 2>&1
run_in_worker "${implicit_warm}" >/dev/null 2>&1

echo ""
echo "Step 4: Run warm cache benchmarks (caches already populated)..."

# Reuse the same show_output_flag from cold cache
if [ "$VERBOSE" = "1" ]; then
  echo "  (Showing Terragrunt output for each run)"
else
  echo "  (Set VERBOSE=1 to see Terragrunt output)"
fi

run_in_worker "hyperfine \
  --runs ${REPS} \
  --warmup 1 \
  --ignore-failure \
  ${show_output_flag} \
  --export-json /workspace/bench-warm.json \
  --export-markdown /workspace/bench-warm.md \
  --command-name 'Explicit (warm cache)' \"${explicit_warm}\" \
  --command-name 'Implicit (warm cache)' \"${implicit_warm}\""

echo ""
echo "Step 5: Generate comparison visualizations..."

cp /tmp/hyperfine/scripts/plot_whisker.py "$ROOT/scripts/"
cp /tmp/hyperfine/scripts/plot_benchmark_comparison.py "$ROOT/scripts/"

if command -v python3 >/dev/null; then
  python3 -c "import matplotlib, numpy" 2>/dev/null || {
    echo "Installing Python dependencies (matplotlib, numpy)..."
    pip3 install matplotlib numpy scipy --quiet --user
  }

  echo "  - Generating cold cache comparison whisker plot..."
  python3 "$ROOT/scripts/plot_whisker.py" "$ROOT/bench-cold.json" \
    --title "Cold Cache: Explicit vs Implicit Stacks" \
    --output "$ROOT/bench-cold-whisker.png"

  echo "  - Generating warm cache comparison whisker plot..."
  python3 "$ROOT/scripts/plot_whisker.py" "$ROOT/bench-warm.json" \
    --title "Warm Cache: Explicit vs Implicit Stacks" \
    --output "$ROOT/bench-warm-whisker.png"

  echo "  - Generating all scenarios comparison..."
  python3 "$ROOT/scripts/plot_all_scenarios.py" \
    "$ROOT/bench-cold.json" "$ROOT/bench-warm.json" \
    --output "$ROOT/bench-all-scenarios.png"

  echo ""
  echo "Visualizations created:"
  echo "   - Cold cache whisker plot: $ROOT/bench-cold-whisker.png"
  echo "   - Warm cache whisker plot: $ROOT/bench-warm-whisker.png"
  echo "   - All scenarios comparison: $ROOT/bench-all-scenarios.png"
else
  echo "WARNING: Python3 not found. Skipping visualization generation."
  echo "   Install Python3 and run:"
  echo "   python3 scripts/plot_whisker.py bench-cold.json --output bench-cold-whisker.png"
  echo "   python3 scripts/plot_whisker.py bench-warm.json --output bench-warm-whisker.png"
fi

echo ""
echo "Benchmark results:"
echo ""
echo "=== COLD CACHE (cache cleared before each run) ==="
cat "$ROOT/bench-cold.md"
echo ""
echo "=== WARM CACHE (cache populated) ==="
cat "$ROOT/bench-warm.md"
echo ""
echo "Raw data:"
echo "   - Cold cache JSON: $ROOT/bench-cold.json"
echo "   - Warm cache JSON: $ROOT/bench-warm.json"
