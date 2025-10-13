#!/usr/bin/env python3
import argparse
import json
import matplotlib.pyplot as plt

parser = argparse.ArgumentParser()
parser.add_argument("file", help="JSON file with benchmark results")
parser.add_argument("--title", help="Plot Title")
parser.add_argument("-o", "--output", help="Save image to the given filename.")

args = parser.parse_args()

with open(args.file, encoding="utf-8") as f:
    results = json.load(f)["results"]

labels = [b["command"] for b in results]
times = [b["times"] for b in results]

fig, ax = plt.subplots(figsize=(10, 7))

bp = ax.boxplot(times, vert=True, patch_artist=True, labels=labels, widths=0.6)

colors = ['#28a745', '#ff8c00']
for patch, color in zip(bp['boxes'], colors):
    patch.set_facecolor(color)
    patch.set_alpha(0.7)
    patch.set_linewidth(2)

for whisker in bp['whiskers']:
    whisker.set(linewidth=2, linestyle='-', color='black')
for cap in bp['caps']:
    cap.set(linewidth=2, color='black')
for median in bp['medians']:
    median.set(linewidth=3, color='darkred')

ax.yaxis.grid(True, linestyle='--', alpha=0.3)
ax.set_axisbelow(True)

ax.set_ylabel('Time (seconds)', fontsize=13, fontweight='bold')
ax.set_xlabel('Scenario', fontsize=13, fontweight='bold')
if args.title:
    ax.set_title(args.title, fontsize=15, fontweight='bold', pad=20)

ax.set_xticklabels(labels, rotation=0, ha='center', fontsize=11)

for i, (times_list, label) in enumerate(zip(times, labels)):
    mean = sum(times_list) / len(times_list)
    min_val = min(times_list)
    max_val = max(times_list)
    y_pos = max_val + (max(map(max, times)) * 0.05)
    stats_text = f"Mean: {mean:.1f}s\nRange: {min_val:.1f}s - {max_val:.1f}s"
    ax.text(i + 1, y_pos, stats_text, ha='center', va='bottom', fontsize=9,
            bbox=dict(boxstyle='round', facecolor='white', alpha=0.8, edgecolor='gray'))

if len(results) == 2:
    explicit_mean = sum(times[0]) / len(times[0])
    implicit_mean = sum(times[1]) / len(times[1])
    speedup = ((implicit_mean - explicit_mean) / explicit_mean) * 100
    speedup_text = f"Explicit is {speedup:.0f}% faster"
    ax.text(0.5, 0.98, speedup_text, transform=ax.transAxes, fontsize=12,
            fontweight='bold', ha='center', va='top',
            bbox=dict(boxstyle='round', facecolor='yellow', alpha=0.7, edgecolor='black'))

plt.tight_layout()

if args.output:
    plt.savefig(args.output, dpi=150, bbox_inches='tight')
    print(f"✓ Saved to {args.output}")
else:
    plt.show()
