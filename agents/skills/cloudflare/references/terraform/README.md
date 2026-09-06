# Cloudflare Terraform provider

Use Terraform when the project owns infrastructure through Terraform. Preserve the existing provider constraint and lockfile; inspect the installed schema before changing resources. The examples in this reference use Cloudflare provider **5.24.0**, checked on 2026-09-05. They are not a reason to upgrade an existing project implicitly.

## Setup

For a new isolated example:

```hcl
terraform {
  required_version = ">= 1.10, < 2.0"
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "= 5.24.0"
    }
  }
}
provider "cloudflare" {}
```

Supply a scoped `CLOUDFLARE_API_TOKEN` through the existing secret mechanism. Do not put it in tracked HCL or command arguments. A Terraform `sensitive` value can still be stored in state and plan files; protect those artifacts and their backend.

## Workflow

```bash
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan -out=tfplan
terraform show tfplan
# After the requested change and its plan are approved for application:
terraform apply tfplan
```

`init` downloads providers; `validate` checks configuration/schema without applying. A plan reads the account and may contain secrets. Applying, importing into state, destroying, or changing state is a separate mutation from inspecting a plan.

Assign one owner to each remote resource or attribute set. Terraform can create KV/R2/D1 resources while Wrangler deploys a Worker referring to their IDs. It must not concurrently overwrite the same Worker settings managed by Terraform. Modules are supported; use existing module boundaries rather than imposing or banning them.

## Existing resources

Use [cf-terraforming](https://developers.cloudflare.com/terraform/advanced-topics/import-cloudflare-resources/) when its installed version supports the target provider/resource. Generated HCL and import commands must be reviewed before execution. Import ID formats are resource-specific; verify the pinned registry page. Importing does not make the configuration match the remote object automatically.

- [configuration.md](configuration.md): v5 resource shapes and examples.
- [api.md](api.md): data sources and IDs.
- [patterns.md](patterns.md): ownership, state and deployment patterns.
- [gotchas.md](gotchas.md): migration, drift and diagnostics.

[Versioned provider reference](https://registry.terraform.io/providers/cloudflare/cloudflare/5.24.0/docs) · [Provider source](https://github.com/cloudflare/terraform-provider-cloudflare/tree/v5.24.0/docs)
