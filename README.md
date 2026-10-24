# terragrunt-cache-test — rigorous Terragrunt benchmarks

Benchmarks Terragrunt **0.68 / 0.89 / 1.2.1** (OpenTofu 1.10.6) in a way that separates
*Terragrunt's own overhead* from OpenTofu work and from network noise.

## Methodology (and why)

Modelled on how Gruntwork benchmarks Terragrunt:

- [`test/benchmarks/`](https://github.com/gruntwork-io/terragrunt/tree/main/test/benchmarks): generated
  near-empty / `null_resource` units (1, 2, 1000 units), an untimed warm-up init before timing,
  A/B variants side by side (e.g. `default_runner` vs `runner_pool`, cache modes), one variable per comparison.
- [Performance docs](https://terragrunt.gruntwork.io/docs/troubleshooting/performance/): use
  [hyperfine](https://github.com/sharkdp/hyperfine) with `--warmup` for end-to-end comparisons.

What this repo does:

| Concern | How it is controlled |
|---|---|
| Network noise | Providers come from a local **filesystem mirror** (`provider_installation`). Module sources are local paths or a local bare git repo over `file://`. Offline suites run inside `unshare -rn` (loopback-only network namespace), so any network access fails the run. |
| OpenTofu time hiding TG overhead | Overhead suite uses a `null_resource` module. A **tofu-only baseline** runs the same plan per unit with plain `tofu` (same parallelism); the summary reports `TG - tofu-only`. |
| Too few iterations | `hyperfine --warmup 3 --runs 10`, JSON export, mean ± stddev, min, max. |
| Flakes | Multi-platform lockfiles pre-generated with `tofu providers lock -fs-mirror` (linux/darwin, amd64/arm64) and committed into every unit. Hyperfine aborts on any non-zero exit, so failed runs never enter the statistics. |
| Cold vs warm mixing | Overhead = warm only (warm-up runs populate `.terragrunt-cache`). Cache = cold only: `hyperfine --prepare` deletes `.terragrunt-cache`, `.terraform`, provider cache dir and `XDG_CACHE_HOME` (auto provider cache + CAS store) before **every** run. |
| Confounded variables | Each row changes one thing: version, layout, auto-provider-cache, CAS, or the cache server. |
| Parallelism | Fixed via `TG_PARALLELISM` / `TERRAGRUNT_PARALLELISM` (= nproc). Default 8. |
| Real cloud | Never used. State backend is `local` (default) or Floci (local AWS emulator) (`BACKEND=floci`, S3 on 127.0.0.1:4566). |

### Fixtures (`bench/gen.py`)

- N units (`--units 30|100|1000`). Dependencies form a fan-out tree: unit *i* depends on unit `(i-1)//3`. That gives chains of depth about log3 N, all through `dependency` blocks with `mock_outputs`.
- Layouts:
  - `implicit`: `root.hcl` (backend) + `env.hcl` (locals, `expose = true`) via `find_in_parent_folders`. Works on all versions.
  - `flat`: the same config inlined, no includes. The difference from `implicit` is the include cost.
  - `explicit`: `terragrunt.stack.hcl` + catalog units that read everything from `values`, with no `find_in_parent_folders`. Needs TG >= 0.78. Generated once outside timing, then run with `--no-stack-generate`.
- `--module cache --source git`: four small providers (null, random, time, local) and a git module source, used to exercise CAS.

### Suites

- **Overhead** (`make overhead`): warm `run --all plan` (`run-all plan` on 0.68). Offline.
- **Cache** (`make cache`): cold `run --all init` on 30 independent units, offline mirror. Compares:
  - tofu-only
  - 0.68 without caching
  - 1.2.1 default (auto provider cache dir + CAS)
  - 1.2.1 with auto cache off (`TG_NO_AUTO_PROVIDER_CACHE_DIR=1`)
  - 1.2.1 with CAS off (`TG_NO_CAS=1`)
- **Cache, registry** (`make cache-registry`): the same, plus the provider cache *server*:
  - 0.68: `TERRAGRUNT_PROVIDER_CACHE=1` + `TERRAGRUNT_PROVIDER_CACHE_DIR`
  - 1.2.1: `TG_PROVIDER_CACHE=1` + `TG_PROVIDER_CACHE_DIR`

  The cache server only proxies remote registries and cannot serve a filesystem mirror, so it can only be measured against registry.opentofu.org. Treat these numbers as network-affected.

## Usage

```sh
make mirror              # one-time, needs network: builds work/mirror
make overhead UNITS="30 100"
make cache
make cache-registry      # optional, networked
make summary             # markdown tables from results/*.json
```

Binaries default to `/workspace/tg-check/bin` (`BIN=...` to override: `tg068`, `tg089`, `terragrunt`, `tofu`).
Requires `hyperfine`, `python3`, `git`, and `unshare` (util-linux). Set `NO_NETNS=1` to skip the namespace, e.g. on macOS.

## Limits

- The numbers are wall-clock time on one machine (8 vCPU). Compare rows within one run, not across machines.
- The tofu-only baseline does not run the `tofu output` calls that Terragrunt makes for dependencies, so `TG - tofu-only` includes dependency-output fetching. That is intentional: it is part of Terragrunt's overhead.
- For micro-level work (parsing, includes), use Terragrunt's own Go benchmarks: `go test -bench . -benchmem ./test/benchmarks`, and compare runs with benchstat.

## Results

See `results/` (hyperfine JSON) and `results/SUMMARY.md`.
