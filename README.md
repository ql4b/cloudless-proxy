# cloudless-proxy

> Clone, configure, deploy. A disposable HTTP proxy with a fresh IP in under a minute.

This is a standalone wrapper around [terraform-aws-ec2-proxy](https://github.com/ql4b/terraform-aws-ec2-proxy) -- the Terraform module that provisions a Squid forward proxy on EC2. If you want to embed the module in a larger infrastructure stack, use the module directly. If you just want a proxy *right now*, clone this repo.

## Quick Start

```bash
git clone https://github.com/ql4b/cloudless-proxy.git
cd cloudless-proxy
cp .env.example .env   # edit with your AWS profile/region
source activate
proxy up
eval $(proxy env)
curl http://httpbin.org/ip   # shows the proxy's IP
```

## Prerequisites

- Terraform >= 1.12 installed (path configured in `.env` via `TERRAFORM_BIN`)
- AWS credentials configured (profile, env vars, or IAM role)
- AWS account with a default VPC (or provide `TF_VAR_vpc_id` and `TF_VAR_subnet_id` for a custom VPC)

## Commands

| Command | Description |
|---------|-------------|
| `proxy up` | Provision the ASG scaffolding and wait until the proxy is serving |
| `proxy down` | Destroy everything |
| `proxy scale-up` | Scale the ASG to 1 — hand out a fresh proxy (new IP), wait until ready |
| `proxy scale-down` | Scale the ASG to 0 — stop cost, keep the scaffolding |
| `proxy recreate` | Terminate current instance + scale back up for a fresh IP |
| `proxy status` | Show instance state, IP, URL, and ASG desired capacity |
| `proxy url` | Print the live proxy URL |
| `proxy test` | Verify the proxy is responding |
| `proxy env` | Print proxy environment variables for export |

> In the underlying module's v3 (ASG) design, `up`/`scale-up`/`recreate` return
> only once Squid is actually serving (they poll the proxy), so the URL they
> print is immediately usable. With `TF_VAR_ttl_hours` set, the instance
> self-terminates after the TTL and the ASG scales itself to zero;
> `proxy scale-up` hands out a fresh one on demand without a `terraform apply`.

### Typical workflow

```bash
source activate          # load .env, add bin/ to PATH
proxy up                 # deploy
eval $(proxy env)        # set HTTP_PROXY/HTTPS_PROXY in current shell
# ... do your work ...
proxy down               # destroy when done
```

### Get a new IP

```bash
proxy recreate           # terminates current instance, deploys a fresh one
eval $(proxy env)        # pick up the new IP
```

## Configuration

Copy `.env.example` to `.env` and adjust:

```bash
AWS_PROFILE=default          # your named AWS CLI profile
AWS_REGION=us-east-1         # region to deploy in
NAMESPACE=myorg              # naming prefix
NAME=proxy                   # resource name

TERRAFORM_VERSION="v1.12.2"
TERRAFORM_BIN="/usr/local/bin/terraform-$TERRAFORM_VERSION"
```

### Optional variables

Set these in `.env` or pass at runtime:

```bash
TF_VAR_ttl_hours=2           # disposable mode: auto-terminate after 2h + scale-to-zero
TF_VAR_instance_type=t4g.micro  # larger instance if needed
TF_VAR_allowed_cidrs='["203.0.113.0/24"]'  # explicit CIDRs (default: auto-detect your IP)
TF_VAR_vpc_id=vpc-abc123     # deploy into a specific VPC (default: region's default VPC)
TF_VAR_subnet_id=subnet-def456  # deploy into a specific public subnet
```

> **Note:** `spot` was removed in the underlying module's v3 (ASG) redesign —
> the proxy is on-demand only. Setting `TF_VAR_spot` now has no effect.

## Region Switching

This wrapper manages **one proxy at a time**, and switching region is a full
teardown-and-redeploy — you cannot move a running proxy between regions.

Two things make this a hard rule rather than a suggestion:

- **Single local state.** There is one `infra/terraform.tfstate`, shared across
  regions. It records the region each resource lives in.
- **The AWS provider pins resources to their creation region.** If you change
  `AWS_REGION` and re-apply *without destroying first*, Terraform keeps the old
  region's resources pinned in state and would create new ones in the target
  region — stranding the old resources (still billable) and splitting state
  across two regions.

To protect against that, `proxy up`/`scale-up`/`scale-down`/`recreate` **refuse
to run** when the region in state differs from `AWS_REGION`, and print the
migration steps. (`proxy down` is *not* guarded — it must be able to destroy the
deployed region, which is step one of a migration.)

Correct migration sequence:

```bash
# 1. Make sure AWS_REGION still points at the CURRENTLY DEPLOYED region.
proxy down                     # destroy in the old region

# 2. Edit AWS_REGION in .env to the new region, then reload:
source activate

# 3. Deploy in the new region:
proxy up
```

If you try to skip the teardown, you'll see:

```
ERROR: region mismatch.
  Terraform state holds resources in: us-west-1
  AWS_REGION is currently set to:      eu-west-1
  ...
```

which walks you through the same steps.

## How It Works

```
cloudless-proxy/
├── .env.example    # configuration template
├── activate        # shell activation script (loads .env, adds bin/ to PATH)
├── bin/proxy       # CLI wrapper (up/down/recreate/status/test/env)
├── tf              # terraform wrapper (reads .env, runs terraform in infra/)
└── infra/          # Terraform config (calls terraform-aws-ec2-proxy module)
```

- `activate` loads your `.env` and puts `bin/` and the repo root on `$PATH`
- `proxy` is a bash script that wraps `tf apply`/`tf destroy` with ergonomic subcommands
- `tf` is a thin wrapper that sources `.env` and calls terraform with `-chdir=infra/`
- `infra/` contains the Terraform configuration that calls the [ql4b/ec2-proxy/aws](https://registry.terraform.io/modules/ql4b/ec2-proxy/aws/latest) module from the Terraform Registry

## What You Get

- EC2 on-demand instance (`t4g.nano` ARM64, Amazon Linux 2023) in a single-node Auto Scaling Group
- Squid HTTP proxy on port 8888
- Security group locked to your IP (auto-detected)
- IMDSv2 enforced, encrypted EBS, no SSH
- SSM access for debugging (`aws ssm start-session`)
- Optional TTL auto-termination with scale-to-zero (no drift)

## Cost

~$0.0042/hour for an on-demand `t4g.nano` in `us-east-1`. Scale to zero (or set
`TF_VAR_ttl_hours`) to drop compute cost to zero between uses. Typical usage
(deploy for an hour, then scale down or destroy) costs about a cent.

## Shell Integration

Source the version-controlled `shell-integration.zsh` from your `~/.zshrc` (or
`~/.bashrc`) to drive the proxy from any directory without `cd`-ing into the
repo or running `source activate` by hand:

```bash
CLOUDLESS_PROXY_PATH="$HOME/code/ql4b/cloudless/cloudless-proxy"  # your clone path
source "$CLOUDLESS_PROXY_PATH/shell-integration.zsh"
```

That defines: `proxy_up`, `proxy_down`, `proxy_scale_up`, `proxy_scale_down`,
`proxy_recreate`, `proxy_status`, `proxy_url`, `proxy_test`, `proxy_env`,
`cloudless_proxy` (drop into the activated repo), and `proxy_mitm` /
`proxy_mitm_browser`. Action commands run in a subshell (no `PATH` pollution,
no leftover cwd); `proxy_env` exports `HTTP_PROXY` et al into your current shell.

Then from any terminal:

```bash
proxy_up                  # deploy + wait until serving
proxy_env                 # export HTTP_PROXY into current shell
curl http://httpbin.org/ip
proxy_scale_down          # park at $0 (keeps the scaffolding)
# ... later ...
proxy_scale_up            # fresh IP, back in ~a minute
proxy_down                # tear everything down
```

### MITM inspection

`shell-integration.zsh` also defines `proxy_mitm`, which chains the cloud proxy
with [mitmproxy](https://mitmproxy.org/) to inspect HTTPS traffic:

```bash
proxy_up
proxy_mitm         # starts mitmproxy on localhost:8080, upstream through cloud proxy
# point browser or curl at http://127.0.0.1:8080
```

## License

Apache 2.0
