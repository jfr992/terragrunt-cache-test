#!/usr/bin/env python3
"""Generate deterministic Terragrunt fixtures for benchmarking.

Layouts:
  implicit  root.hcl + env.hcl includes (find_in_parent_folders), all TG versions
  flat      same config inlined, no includes (measures include cost)
  explicit  terragrunt.stack.hcl + catalog units driven by `values` (TG >= 0.78)
Every unit except u0000 depends on parent (i-1)//FANOUT -> fan-out tree with
dependency chains of depth ~log_FANOUT(N). Dependencies use mock_outputs.
"""
import argparse, os, shutil, subprocess, textwrap

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PLATFORMS = ["linux_amd64", "linux_arm64", "darwin_amd64", "darwin_arm64"]

MODULES = {
 "null": '''terraform {
  required_providers {
    null = { source = "hashicorp/null", version = "3.2.4" }
  }
}
variable "in"  { default = "" }
variable "env" { default = "" }
resource "null_resource" "x" { triggers = { in = var.in, env = var.env } }
output "id" { value = "id-${var.env}" }
''',
 "cache": '''terraform {
  required_providers {
    null   = { source = "hashicorp/null", version = "3.2.4" }
    random = { source = "hashicorp/random", version = "3.7.2" }
    time   = { source = "hashicorp/time", version = "0.13.1" }
    local  = { source = "hashicorp/local", version = "2.5.3" }
  }
}
variable "in"  { default = "" }
variable "env" { default = "" }
resource "null_resource" "x" { triggers = { in = var.in } }
resource "random_id" "x" { byte_length = 4 }
resource "time_static" "x" {}
output "id" { value = "id-${var.env}" }
''',
}

def w(path, s):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f: f.write(textwrap.dedent(s).lstrip())

def backend(kind):
    if kind == "floci":  # local AWS emulator (Floci) on 127.0.0.1:4566, never real cloud
        return '''remote_state {
  backend  = "s3"
  generate = { path = "backend.tf", if_exists = "overwrite_terragrunt" }
  config = {
    bucket = "tg-bench-state", key = "${path_relative_to_include()}/tf.tfstate", region = "us-east-1"
    endpoints = { s3 = "http://127.0.0.1:4566" }
    use_path_style = true, skip_credentials_validation = true, skip_requesting_account_id = true
    skip_metadata_api_check = true, skip_region_validation = true, skip_bucket_versioning = true
    skip_bucket_ssencryption = true, skip_bucket_root_access = true, skip_bucket_enforced_tls = true
    disable_bucket_update = true, access_key = "test", secret_key = "test"
  }
}
'''
    return '''remote_state {
  backend  = "local"
  generate = { path = "backend.tf", if_exists = "overwrite_terragrunt" }
  config   = { path = "${get_terragrunt_dir()}/terraform.tfstate" }
}
'''

DEP = '''dependency "parent" {
  config_path = "%s"
  mock_outputs = { id = "mock" }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate"]
}
'''

def main():
    a = argparse.ArgumentParser()
    a.add_argument("--units", type=int, default=30)
    a.add_argument("--layout", choices=["implicit", "flat", "explicit"], default="implicit")
    a.add_argument("--module", choices=["null", "cache"], default="null")
    a.add_argument("--source", choices=["local", "git"], default="local",
                   help="git = local bare repo via file:// (exercises CAS, no network)")
    a.add_argument("--backend", choices=["local", "floci"], default="local")
    a.add_argument("--fanout", type=int, default=3)
    a.add_argument("--no-deps", action="store_true")
    a.add_argument("--mirror", default=os.path.join(ROOT, "work", "mirror"))
    a.add_argument("--tofu", default=os.environ.get("TOFU", "tofu"))
    a.add_argument("--out", required=True)
    o = a.parse_args()
    out = os.path.abspath(o.out); mirror = os.path.abspath(o.mirror)
    shutil.rmtree(out, ignore_errors=True); os.makedirs(out)

    # CLI configs: filesystem mirror only (no network) vs plain registry.
    w(f"{out}/tofurc-mirror", f'''provider_installation {{
  filesystem_mirror {{
    path    = "{mirror}"
    include = ["registry.opentofu.org/*/*", "registry.terraform.io/*/*"]
  }}
}}
''')
    w(f"{out}/tofurc-registry", 'provider_installation {\n  direct {}\n}\n')

    mod = f"{out}/modules/{o.module}"
    w(f"{mod}/main.tf", MODULES[o.module])
    # Multi-platform lockfile, pre-generated from the mirror (deterministic, no checksum flakes).
    lk = f"{out}/.lockgen"; w(f"{lk}/main.tf", MODULES[o.module].split("variable")[0])
    subprocess.run([o.tofu, f"-chdir={lk}", "providers", "lock", f"-fs-mirror={mirror}"]
                   + [f"-platform={p}" for p in PLATFORMS], check=True, stdout=subprocess.DEVNULL)
    lock = open(f"{lk}/.terraform.lock.hcl").read(); shutil.rmtree(lk)
    w(f"{mod}/.terraform.lock.hcl", lock)

    if o.source == "git":
        work = f"{out}/.gitsrc"; shutil.copytree(f"{out}/modules", work)
        g = lambda *x: subprocess.run(["git", "-C", work, *x], check=True, capture_output=True)
        g("init", "-q", "-b", "main"); g("add", "-A")
        g("-c", "user.name=b", "-c", "user.email=b@b", "commit", "-qm", "m"); g("tag", "v1")
        subprocess.run(["git", "clone", "-q", "--bare", work, f"{out}/modules.git"], check=True)
        shutil.rmtree(work)
        src = lambda rel: f"git::file://{out}/modules.git//{o.module}?ref=v1"
    else:
        src = lambda rel: rel

    names = [f"u{i:04d}" for i in range(o.units)]
    parent = lambda i: None if (i == 0 or o.no_deps) else names[(i - 1) // o.fanout]

    if o.layout in ("implicit", "flat"):
        live = f"{out}/live"
        if o.layout == "implicit":
            w(f"{live}/root.hcl", backend(o.backend))
            w(f"{live}/env/env.hcl", 'locals {\n  env    = "bench"\n  region = "us-east-1"\n}\n')
        for i, n in enumerate(names):
            d = f"{live}/env/{n}"
            if o.layout == "implicit":
                hdr = ('include "root" {\n  path = find_in_parent_folders("root.hcl")\n}\n'
                       'include "env" {\n  path   = find_in_parent_folders("env.hcl")\n  expose = true\n}\n')
                env = "include.env.locals.env"
            else:
                hdr = backend(o.backend) + 'locals {\n  env    = "bench"\n  region = "us-east-1"\n}\n'
                env = "local.env"
            body = hdr + f'terraform {{\n  source = "{src("../../../modules/" + o.module)}"\n}}\n'
            p = parent(i)
            if p:
                body += DEP % f"../{p}"
                body += f'inputs = {{\n  in  = dependency.parent.outputs.id\n  env = {env}\n}}\n'
            else:
                body += f'inputs = {{\n  env = {env}\n}}\n'
            w(f"{d}/terragrunt.hcl", body); w(f"{d}/.terraform.lock.hcl", lock)
    else:  # explicit stack: catalog units take everything from `values`, no find_in_parent_folders
        cat = f"{out}/catalog/units"
        common = backend(o.backend) + 'terraform {\n  source = values.module\n}\n'
        w(f"{cat}/root/terragrunt.hcl", common + 'inputs = {\n  env = values.env\n}\n')
        w(f"{cat}/node/terragrunt.hcl", common + (DEP % '${values.parent}') +
          'inputs = {\n  in  = dependency.parent.outputs.id\n  env = values.env\n}\n')
        for u in ("root", "node"): w(f"{cat}/{u}/.terraform.lock.hcl", lock)
        modsrc = src(mod)
        blocks = []
        for i, n in enumerate(names):
            p = parent(i)
            vals = f'module = "{modsrc}", env = "bench"' + (f', parent = "../{p}"' if p else "")
            blocks.append(f'unit "{n}" {{\n  source = "../catalog/units/{"node" if p else "root"}"\n'
                          f'  path   = "{n}"\n  values = {{ {vals} }}\n}}\n')
        w(f"{out}/live/terragrunt.stack.hcl", "\n".join(blocks))

    # Plain-tofu baseline: same module + backend per unit, no Terragrunt.
    for n in names:
        d = f"{out}/tofu/{n}"
        w(f"{d}/main.tf", MODULES[o.module])
        w(f"{d}/backend.tf", 'terraform {\n  backend "local" {}\n}\n')
        w(f"{d}/terraform.tfvars", 'in = "mock"\nenv = "bench"\n')
        w(f"{d}/.terraform.lock.hcl", lock)
    print(out)

if __name__ == "__main__":
    main()
