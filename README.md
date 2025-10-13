# Quick Test - 4 Steps to Run Benchmark

Run these commands to test the benchmark in ~15 minutes:

## Step 0: Generate Certificates (First Time Only)

```bash
make gen-certs
```

This creates the certificates for boring-registry.

## Step 1: Start Services

```bash
make up
```

## Step 2: Run Benchmark

```bash
make bench-graphs
```

This will:
- Clear caches
- Run 3 cold cache tests (both explicit and implicit)
- Warm up caches
- Run 3 warm cache tests
- Generate graphs

Takes ~10-15 minutes total.

## Step 3: View Results (MACOS)

```bash
open benchmark-runs/run-1/bench-all-scenarios.png
```

Or view all results:

```bash
open benchmark-runs/run-1/*.png
cat bench-cold.md
cat bench-warm.md
```
