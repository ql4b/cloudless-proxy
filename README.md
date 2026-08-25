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
- AWS account with a default VPC

## Commands

| Command | Description |
|---------|-------------|
| `proxy up` | Provision the proxy instance |
| `proxy down` | Destroy the instance |
| `proxy recreate` | Terminate + reprovision for a fresh IP |
| `proxy status` | Show instance state, IP, and proxy URL |
| `proxy test` | Verify the proxy is responding |
| `proxy env` | Print proxy environment variables for export |

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
TF_VAR_spot=false            # use on-demand instead of spot
TF_VAR_ttl_hours=2           # auto-terminate after 2 hours
TF_VAR_instance_type=t4g.micro  # larger instance if needed
TF_VAR_allowed_cidrs='["203.0.113.0/24"]'  # explicit CIDRs (default: auto-detect your IP)
```

## Region Switching

The proxy is stateless -- switching region means a full redeploy:

```bash
# edit AWS_REGION in .env, then:
source activate
proxy down    # destroy in old region
proxy up      # provision in new region
```

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

- EC2 spot instance (`t4g.nano` ARM64, Amazon Linux 2023)
- Squid HTTP proxy on port 8888
- Security group locked to your IP (auto-detected)
- IMDSv2 enforced, encrypted EBS, no SSH
- SSM access for debugging (`aws ssm start-session`)
- Optional TTL auto-termination

## Cost

~$0.0016/hour for `t4g.nano` spot in `us-east-1`. Typical usage (deploy for an hour, destroy) costs less than a cent.

## License

Apache 2.0
