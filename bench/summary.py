#!/usr/bin/env python3
"""Summarize hyperfine JSON exports: mean ± stddev, median, min, max, overhead vs the tofu-only baseline.

Reads results/*.json and results/*/*.json (e.g. results/reduced/), so reduced-run files are included.
"""
import glob, json, os, sys
d = sys.argv[1] if len(sys.argv) > 1 else "results"
for f in sorted(glob.glob(f"{d}/*.json") + glob.glob(f"{d}/*/*.json")):
    r = json.load(open(f))["results"]
    base = next((x["mean"] for x in r if x["command"] == "tofu-only"), None)
    print(f"\n### {os.path.relpath(f, d)[:-5]}\n")
    print("| command | mean ± stddev (s) | median | min | max | runs | overhead vs tofu-only (s, mean) |")
    print("|---|---|---|---|---|---|---|")
    for x in r:
        ov = f"{x['mean'] - base:+.2f}" if base and x["command"] != "tofu-only" else ""
        warn = " (n<5)" if len(x["times"]) < 5 else ""
        print(f"| {x['command']} | {x['mean']:.3f} ± {x['stddev']:.3f} | {x['median']:.3f} | {x['min']:.3f} | "
              f"{x['max']:.3f} | {len(x['times'])}{warn} | {ov} |")
