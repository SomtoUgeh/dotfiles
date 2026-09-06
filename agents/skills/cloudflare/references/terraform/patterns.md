# Terraform ownership and deployment patterns

## Environments and modules

Reuse the project's environment/module layout. Separate production and staging state and identities when they manage independent resources. Shared resources need one state owner and explicit outputs. Terraform modules are supported; provider auto-generation does not prohibit them.

A reusable zone module can accept `account_id`, `domain` and `ssl_mode`, then create the zone and individual `cloudflare_zone_setting` resources shown in [configuration.md](configuration.md). Supply values through normal module arguments, not semicolon-delimited pseudo-HCL.

## Remote state

Use an existing backend with encryption, access controls, recoverable versions and locking. `sensitive = true` hides terminal output; it does not encrypt values in the state file.

An S3-compatible R2 backend fragment for a Terraform version supporting these settings:

```hcl
terraform {
  backend "s3" {
    bucket                      = "terraform-state"
    key                         = "production/cloudflare.tfstate"
    region                      = "auto"
    endpoints                   = { s3 = "https://ACCOUNT_ID.r2.cloudflarestorage.com" }
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
    use_lockfile                = true
  }
}
```

Supply backend credentials through the established secret mechanism. Verify conditional lockfile operations with the chosen backend and Terraform version before concurrent writes; do not infer that any S3-compatible service implements every S3 feature. This fragment has no provisioned bucket, state retention or account access by itself.

## Terraform infrastructure, Wrangler deployment

A valid split is Terraform owning KV/R2/D1 and exporting IDs while Wrangler owns the Worker deployment and binding declarations. Avoid simultaneous Terraform `cloudflare_workers_script` ownership of that same Worker.

1. Plan the infrastructure changes and review the saved plan.
2. Apply the authorized plan using the project's CI environment controls.
3. Read the resulting non-secret IDs.
4. Update the intended Wrangler bindings with a structured JSON/TOML operation.
5. Build/type-check/dry-run, then deploy through the existing authorized pipeline.

Unrestricted `envsubst` can replace unrelated `$` expressions or corrupt JSON. If the project already uses a template, substitute only a named allowlist and validate the result. Do not add `terraform apply -auto-approve` merely to make an example non-interactive.

## Common assemblies

| Goal | Resources and checks |
|---|---|
| Static site plus API | Pages project/deployment, API Worker, correct route and DNS ownership; bind D1 with the current v5 `bindings` list. |
| Geographic load balancing | Pools with explicit `origins`, `default_pools`, `fallback_pool` and a `region_pools` map; verify entitlement and healthy fallback behavior. |
| Protected admin surface | Access application plus attached reusable policy; preserve the existing IdP and check every public alias/origin. |
| Worker gradual rollout | Explicitly chosen beta Worker/version/deployment lifecycle, compatible bindings/migrations and rollback plan. |

See [configuration.md](configuration.md) for schema-correct resource shapes. Planning validates intended account changes; local syntax/schema checks alone do not prove a deployment or migration succeeds.
