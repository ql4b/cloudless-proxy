# Project Overview

## What This Is

`cloudless-proxy` is a **standalone wrapper** around the
[terraform-aws-ec2-proxy](https://github.com/ql4b/terraform-aws-ec2-proxy)
module. It exists so you can get a disposable HTTP proxy with a fresh public IP
by cloning a repo and running one command — no Terraform to write yourself.

- Want to embed the proxy in a larger stack → use the module directly.
- Just want a proxy right now → clone this wrapper.

## Repository Layout

```
.
├── .env.example    # config template (copied to .env, which is gitignored)
├── activate        # `source activate` — loads .env, puts bin/ + repo root on PATH
├── bin/proxy       # the lifecycle CLI (up/down/scale-up/scale-down/status/…)
├── tf              # thin terraform wrapper: sources .env, runs `terraform -chdir=infra`
├── infra/          # Terraform root that calls the ec2-proxy module
│   ├── main.tf     # module "proxy" (pinned to ql4b/ec2-proxy/aws ~> 3.0) + null-label
│   ├── variables.tf
│   ├── outputs.tf  # asg_name, launch_template_id, region, instance_type, ttl_hours
│   └── versions.tf # provider "aws" { region = var.region, profile = var.profile }
├── site/           # Astro landing page for proxy.cloudless.sh (untracked; deployed separately)
└── README.md
```

## Configuration

Everything is driven by `.env` (gitignored — it holds the real AWS profile/region):

- `AWS_PROFILE`, `AWS_REGION` — the CLI and, via `TF_VAR_region`/`TF_VAR_profile`, the provider.
- `NAMESPACE`, `NAME` — null-label naming; the module id is `<namespace>-<name>`.
- `TF_VAR_ttl_hours`, `TF_VAR_instance_type`, `TF_VAR_allowed_cidrs`, `TF_VAR_vpc_id`, `TF_VAR_subnet_id` — optional passthroughs.
- `TERRAFORM_BIN` — which terraform binary `tf` invokes.

## Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| **Consumes the module at `~> 3.0`** | Tracks the ASG-based v3 line; `terraform apply` provisions the ASG, the CLI drives its capacity. |
| **CLI owns runtime, Terraform owns scaffolding** | The module's `desired_capacity` is `ignore_changes`, so the running instance is managed out-of-band by `bin/proxy` (scale-up/down), not by apply. |
| **Resolve the instance live by tag** | The proxy IP is NOT a Terraform output (the ASG instance is dynamic). `bin/proxy` reads the running instance from EC2 by the `proxy:managed-by` tag, and the TTL from the `proxy:ttl-hours` tag. |
| **Readiness = Squid answering, not "instance running"** | `up`/`scale-up`/`recreate` poll in two phases (instance running, then proxy responds) so a printed URL is immediately usable. |
| **One proxy at a time; region switch = destroy-first** | Single local state + AWS provider v6 pinning resources to their creation region means a naive region switch strands resources. `bin/proxy` guards mutating commands against a region mismatch and prints the migration steps. |
| **All AWS calls go through the `_aws` wrapper** | Strips `HTTP(S)_PROXY` in-process (so we never route AWS calls through the managed proxy), sets timeouts, disables the pager — prevents hangs. |
| **Local ephemeral state** | No remote backend; deploy/destroy per use. State lives in `infra/terraform.tfstate` (gitignored). |

## bin/proxy Commands

| Command | Description |
|---------|-------------|
| `up` | apply + ensure scaled up + wait until serving (scales up itself if the ASG is at 0) |
| `down` | `terraform destroy` (the only unguarded mutation — it is region-migration step one) |
| `scale-up` / `scale-down` | set ASG desired to 1 / 0 (hand out a proxy / stop cost, keep scaffolding) |
| `recreate` | terminate current instance, then scale up — fresh IP |
| `status` | region, instance id/ip/state/url, ASG desired, TTL |
| `url` | live proxy URL (resolve-by-tag) |
| `test` / `env` | curl through the proxy / print `export` lines for `eval` |
