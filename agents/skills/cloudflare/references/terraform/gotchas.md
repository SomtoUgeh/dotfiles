# Terraform troubleshooting

## Provider and schema drift

The version constraint selects allowed versions; `.terraform.lock.hcl` records the installed version and checksums. Inspect both. A v4-to-v5 upgrade changes resource names, nested blocks and state schemas; it is not a global string replacement. Worker resources are not all plural: `cloudflare_worker` and `cloudflare_worker_version` exist alongside `cloudflare_workers_script`.

Do not prescribe `terraform state mv` between resource types without verifying provider support. Follow the [migration guide](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/guides/version-5-migration), retain recoverable state, and review a plan before applying.

## Common failures

| Failure | Correction |
|---|---|
| HCL rejects semicolons or nested blocks | Put arguments on separate lines; use the pinned v5 object/list schema. |
| Worker fields `name`, `module`, or `*_binding` rejected | Script resources use `script_name`, `main_module` and `bindings = [...]`. |
| Secret changes disappear from plans | An `ignore_changes` rule may suppress intended rotation. Remove broad ignores; diagnose the actual provider defect/ownership first. |
| Pages deployment configuration always differs | Compare computed/default fields with the pinned schema. Do not ignore all `deployment_configs`, which would hide binding and security changes. |
| Resource absent remotely | Decide whether the desired configuration should recreate it or deliberately stop managing it. Import cannot restore an object that does not exist. |
| Existing DNS record conflicts | Import the correct ID and reconcile its configuration before applying. |
| Locked state | Confirm no writer still owns the lock. Only unlock the identified stale lock; do not bypass locking during a concurrent run. |
| D1 is created without tables | Apply the project's migrations to the intended remote database. `wrangler d1 migrations apply NAME --remote` changes that account; omitting `--remote` can target local development instead. |
| Deployment too large | Measure the built artifact against current Worker limits. Code splitting does not remove dependencies from the deployed total. |

Use provider diagnostics without dumping credentials or sensitive state into logs. `api_client_logging` is not a general provider setting to copy blindly. API quotas, DNS counts, Pages projects and Worker size limits vary over time and by plan; retrieve the current product limits for the actual account.

Use the required uppercase R2 location values from the pinned schema. Pinning an old version to work around drift is a temporary choice with a concrete issue and upgrade test, not an indefinite recommendation.

[Configuration examples](configuration.md) · [Provider reference](https://registry.terraform.io/providers/cloudflare/cloudflare/5.24.0/docs)
