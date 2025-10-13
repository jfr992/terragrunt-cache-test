#!/usr/bin/env python3
import json
import matplotlib.pyplot as plt
import numpy as np
import argparse
from matplotlib.patches import Patch

parser = argparse.ArgumentParser()
parser.add_argument("cold_file", help="JSON file with cold cache results")
parser.add_argument("warm_file", help="JSON file with warm cache results")
parser.add_argument("--output", "-o", help="Save image to the given filename")
parser.add_argument("--title", help="Plot title")

args = parser.parse_args()

with open(args.cold_file) as f:
    cold_data = json.load(f)["results"]

with open(args.warm_file) as f:
    warm_data = json.load(f)["results"]

scenarios = [
    "Explicit\n(cold cache)",
    "Explicit\n(warm cache)",
    "Implicit\n(cold cache)",
    "Implicit\n(warm cache)"
]

means = [
    cold_data[0]["mean"],
    warm_data[0]["mean"],
    cold_data[1]["mean"],
    warm_data[1]["mean"],
]

stdevs = [
    cold_data[0]["stddev"],
    warm_data[0]["stddev"],
    cold_data[1]["stddev"],
    warm_data[1]["stddev"],
]

colors = ['#28a745', '#90ee90', '#ff8c00', '#ffa500']

fig, ax = plt.subplots(figsize=(12, 7))
x_pos = np.arange(len(scenarios))
bars = ax.bar(x_pos, means, yerr=stdevs, capsize=5, color=colors,
               edgecolor='black', linewidth=1.5, alpha=0.8)

ax.set_xlabel('Scenario', fontsize=12, fontweight='bold')
ax.set_ylabel('Time (seconds)', fontsize=12, fontweight='bold')
ax.set_title(args.title or 'Terragrunt Stack Performance: All Scenarios',
             fontsize=14, fontweight='bold', pad=20)
ax.set_xticks(x_pos)
ax.set_xticklabels(scenarios, fontsize=11)
ax.grid(axis='y', alpha=0.3, linestyle='--')

for i, (bar, mean, stddev) in enumerate(zip(bars, means, stdevs)):
    height = bar.get_height()
    ax.text(bar.get_x() + bar.get_width()/2., height + stddev + 2,
            f'{mean:.1f}s\n±{stddev:.1f}s',
            ha='center', va='bottom', fontsize=10, fontweight='bold')

explicit_cold = means[0]
explicit_warm = means[1]
implicit_cold = means[2]
implicit_warm = means[3]

speedup_cold = ((implicit_cold - explicit_cold) / explicit_cold) * 100
speedup_warm = ((implicit_warm - explicit_warm) / explicit_warm) * 100
cache_benefit_explicit = ((explicit_cold - explicit_warm) / explicit_cold) * 100
cache_benefit_implicit = ((implicit_cold - implicit_warm) / implicit_cold) * 100

textstr = '\n'.join([
    f'Explicit Speedup (cold): {speedup_cold:.0f}% faster',
    f'Explicit Speedup (warm): {speedup_warm:.0f}% faster',
    f'Cache Benefit (explicit): {cache_benefit_explicit:.0f}% faster',
    f'Cache Benefit (implicit): {cache_benefit_implicit:.0f}% faster'
])

props = dict(boxstyle='round', facecolor='wheat', alpha=0.8)
ax.text(0.98, 0.97, textstr, transform=ax.transAxes, fontsize=10,
        verticalalignment='top', horizontalalignment='right', bbox=props)

legend_elements = [
    Patch(facecolor='#28a745', edgecolor='black', label='Explicit Stack'),
    Patch(facecolor='#ff8c00', edgecolor='black', label='Implicit Stack')
]
ax.legend(handles=legend_elements, loc='upper left', fontsize=11)

plt.tight_layout()

if args.output:
    plt.savefig(args.output, dpi=150, bbox_inches='tight')
    print(f"Saved to {args.output}")
else:
    plt.show()
