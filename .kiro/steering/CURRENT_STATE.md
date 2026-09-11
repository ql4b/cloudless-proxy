# Current State

*Last updated: 2026-09-10*

## Status: on ec2-proxy v3 (ASG), operational

The wrapper consumes `ql4b/ec2-proxy/aws` `~> 3.0` (currently resolves v3.1.0)
and provides a full lifecycle CLI over the ASG-based proxy. Deployed and
live-validated (us-west-1, then migrated to eu-south-1).

## What Works

- **`bin/proxy` lifecycle CLI** — `up`, `down`, `scale-up`, `scale-down`,
  `recreate`, `status`, `url`, `wait`, `test`, `env`.
- **Resolve-by-tag** — the running instance is found live from EC2 by the
  `proxy:managed-by` tag (not a Terraform output, which would be stale for a
  dynamic ASG instance). TTL is read from the `proxy:ttl-hours` tag.
- **Two-phase readiness** — `up`/`scale-up`/`recreate` wait for (1) a running
  instance, then (2) Squid actually answering, before returning. The URL they
  print is immediately usable.
- **Progress output** — phase-boundary messages with elapsed time, on stderr
  (stdout stays clean for capture).
- **Region wiring + guard** — the provider is wired to `var.region`/`var.profile`;
  mutating commands refuse when the region in state differs from `AWS_REGION`
  and print the destroy-first migration steps (`down` is unguarded).
- **`status` always shows region** (even with no instance) and distinguishes
  "not deployed" from "scaled to zero"; shows the TTL when set.
- **`up` is scale-to-zero safe** — because `desired_capacity` is `ignore_changes`
  in the module, `apply` won't reset it to 1; `up` detects a desired-0 ASG and
  scales it up itself (with a warning) instead of hanging.
- **Hardened AWS calls** — a single `_aws` wrapper strips `HTTP(S)_PROXY`
  in-process, sets connect/read timeouts, and disables the CLI pager.

## Known Limitations / Notes

1. **One proxy at a time.** Single local state; switching region is a full
   destroy-and-redeploy (enforced by the region guard). No per-region parallel
   proxies.
2. **Brief downtime on recycle** (terminate → launch → Squid install, ~1 min) —
   inherited from the module's disposable design.
3. **Local ephemeral state** — `infra/terraform.tfstate` is gitignored; there is
   no remote backend or shared state.
4. **`site/` is untracked** — the Astro landing page is deployed separately and
   intentionally not committed to this repo.
5. **No CI / release automation** — unlike the module, the wrapper has no
   semantic-release or GitHub Actions; small fixes go straight to `main`.

## Dependencies

| Dependency | Version | Notes |
|------------|---------|-------|
| terraform-aws-ec2-proxy | `~> 3.0` (registry) | The ASG-based proxy module |
| Terraform | `~> 1.12` | Per `infra/versions.tf` (`TERRAFORM_BIN` in `.env`) |
| AWS Provider | `~> 6.5` | Region/profile from `var.region`/`var.profile` |
| AWS CLI v2 | — | Used by `bin/proxy`; pager disabled via `AWS_PAGER=""` |
| cloudposse/label/null | 0.25.0 | Naming/tagging (matches the module) |
