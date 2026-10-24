#!/usr/bin/env python3
"""Summarize hyperfine JSON exports: mean ± stddev, min, max, relative to fastest/baseline."""
import glob, json, os, sys
d = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "results")
for f in sorted(glob.glob(f"{d}/*.json")):
    r = json.load(open(f))["results"]
    base = next((x["mean"] for x in r if x["command"] == "tofu-only"), None)
    print(f"\n## {os.path.basename(f)[:-5]}\n")
    print("| command | mean ± stddev (s) | min | max | runs | minus tofu-only |")
    print("|---|---|---|---|---|---|")
    for x in r:
        ov = f"{x['mean'] - base:+.2f}" if base and x["command"] != "tofu-only" else ""
        print(f"| {x['command']} | {x['mean']:.3f} ± {x['stddev']:.3f} | {x['min']:.3f} | "
              f"{x['max']:.3f} | {len(x['times'])} | {ov} |")
