#!/usr/bin/env python3
"""Drive hyperfine for the overhead and cache suites. Any non-zero exit fails the run."""
import argparse, os, shlex, shutil, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BIN = os.environ.get("BENCH_BIN", "/workspace/tg-check/bin")
TOFU = os.environ.get("TOFU", f"{BIN}/tofu")
P = os.environ.get("PARALLELISM", str(os.cpu_count()))
VERSIONS = {  # label: (binary, run-all syntax, supports stacks)
    "tg068": (f"{BIN}/tg068", "run-all", False),
    "tg089": (f"{BIN}/tg089", "run --all", True),
    "tg121": (f"{BIN}/terragrunt", "run --all", True),
}

def gen(out, *args):
    subprocess.run([sys.executable, f"{ROOT}/bench/gen.py", "--out", out, *args],
                   check=True, env={**os.environ, "TOFU": TOFU}, stdout=subprocess.DEVNULL)

def base_env(fx, registry=False):
    rc = f"{fx}/tofurc-{'registry' if registry else 'mirror'}"
    return ("export " f"TF_CLI_CONFIG_FILE={rc} TG_TF_PATH={TOFU} TERRAGRUNT_TFPATH={TOFU} "
            f"TG_PARALLELISM={P} TERRAGRUNT_PARALLELISM={P} XDG_CACHE_HOME={fx}/.xdg "
            f"TG_NON_INTERACTIVE=true TERRAGRUNT_NON_INTERACTIVE=true;")

def tg(ver, sub, extra=""):
    b, ra, _ = VERSIONS[ver]
    return f"{b} {ra} {extra} {sub}"

def baseline(fx, sub):
    return (f"ls -d {fx}/tofu/u* | xargs -P{P} -I{{}} {TOFU} -chdir={{}} {sub} -input=false "
            f"{'-lock=false' if sub == 'plan' else ''} -no-color")

def offline(cmd):
    """Run inside a fresh network namespace (loopback only): proves zero network use."""
    if os.environ.get("NO_NETNS") or not shutil.which("unshare"):
        return cmd
    return "unshare -rn bash -c " + shlex.quote("ip link set lo up 2>/dev/null; " + cmd)

def hyperfine(out_json, cmds, warmup, runs, prepare=None, setup=None):
    a = ["hyperfine", "--shell=bash", "--style=basic", "--warmup", str(warmup),
         "--runs", str(runs), "--export-json", out_json]
    if setup: a += ["--setup", setup]
    for name, cmd in cmds:
        if prepare: a += ["--prepare", prepare]
        a += ["-n", name, cmd]
    print("+", " ".join(a[:12]), "...", flush=True)
    subprocess.run(a, check=True)

def overhead(o):
    for n in o.units:
        cmds = []
        for lay in o.layouts:
            fx = f"{o.work}/overhead-{lay}-{n}"
            gen(fx, "--units", str(n), "--layout", lay, "--backend", o.backend)
            env = base_env(fx)
            for v in o.versions:
                if lay == "explicit" and not VERSIONS[v][2]: continue
                if lay == "explicit":
                    subprocess.run(f"cd {fx}/live && {env} {VERSIONS[v][0]} stack generate",
                                   shell=True, check=True, capture_output=True)
                    c = f"cd {fx}/live && {env} {tg(v, 'plan', '--no-stack-generate')}"
                else:
                    c = f"cd {fx}/live && {env} {tg(v, 'plan')}"
                cmds.append((f"{v}-{lay}", c))
            if lay == o.layouts[0]:
                subprocess.run(f"{env} {baseline(fx, 'init')} >/dev/null", shell=True, check=True)
                cmds.append(("tofu-only", f"{env} {baseline(fx, 'plan')}"))
        cmds = [(k, offline(c)) for k, c in cmds]
        hyperfine(f"{o.results}/overhead-{n}.json", cmds, o.warmup, o.runs)

def cache(o):
    n = o.units[0]
    fx = f"{o.work}/cache-{n}"
    gen(fx, "--units", str(n), "--module", "cache", "--source", "git", "--no-deps", "--backend", o.backend)
    env = base_env(fx, o.registry)
    pc = f"{fx}/.pcache"
    # Fresh state before EVERY timed run: no .terragrunt-cache, .terraform, provider cache, CAS store.
    prep = (f"find {fx}/live {fx}/tofu -name .terragrunt-cache -prune -exec rm -rf {{}} + ; "
            f"find {fx}/tofu -name .terraform -prune -exec rm -rf {{}} + ; rm -rf {fx}/.xdg {pc}")
    live = f"cd {fx}/live && {env}"
    cmds = [
        ("tofu-only", f"{env} {baseline(fx, 'init')}"),
        ("tg068-none", f"{live} {tg('tg068', 'init')}"),
        ("tg121-default(auto+cas)", f"{live} {tg('tg121', 'init')}"),
        ("tg121-auto-off", f"{live} TG_NO_AUTO_PROVIDER_CACHE_DIR=1 {tg('tg121', 'init')}"),
        ("tg121-cas-off", f"{live} TG_NO_CAS=1 {tg('tg121', 'init')}"),
    ]
    if o.registry:
        # The provider cache *server* proxies remote registries only; it cannot serve a
        # filesystem mirror, so it is only benchmarked in --registry mode (network noise!).
        cmds += [
            ("tg068-cache-server", f"{live} TERRAGRUNT_PROVIDER_CACHE=1 TERRAGRUNT_PROVIDER_CACHE_DIR={pc} {tg('tg068', 'init')}"),
            ("tg121-cache-server", f"{live} TG_PROVIDER_CACHE=1 TG_PROVIDER_CACHE_DIR={pc} {tg('tg121', 'init')}"),
        ]
    else:
        cmds = [(k, offline(c)) for k, c in cmds]
    tag = "registry" if o.registry else "mirror"
    hyperfine(f"{o.results}/cache-{n}-{tag}.json", cmds, o.warmup, o.runs, prepare=prep)

if __name__ == "__main__":
    a = argparse.ArgumentParser()
    a.add_argument("suite", choices=["overhead", "cache"])
    a.add_argument("--units", type=int, nargs="+", default=[30])
    a.add_argument("--versions", nargs="+", default=list(VERSIONS))
    a.add_argument("--layouts", nargs="+", default=["implicit", "flat", "explicit"])
    a.add_argument("--backend", choices=["local", "floci"], default="local")
    a.add_argument("--registry", action="store_true", help="cache suite: download from registry (network!)")
    a.add_argument("--warmup", type=int, default=3)
    a.add_argument("--runs", type=int, default=10)
    a.add_argument("--work", default=f"{ROOT}/work")
    a.add_argument("--results", default=f"{ROOT}/results")
    o = a.parse_args()
    os.makedirs(o.results, exist_ok=True)
    {"overhead": overhead, "cache": cache}[o.suite](o)
