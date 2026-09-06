## Wrangler Configuration

### Basic Container Config

```jsonc
{
  "name": "my-worker",
  "main": "src/index.ts",
  "compatibility_date": "2026-01-10",
  "containers": [
    {
      "class_name": "MyContainer",
      "image": "./Dockerfile",  // Path to Dockerfile or directory with Dockerfile
      "instance_type": "standard-1",  // Predefined or custom (see below)
      "max_instances": 10
    }
  ],
  "durable_objects": {
    "bindings": [
      {
        "name": "MY_CONTAINER",
        "class_name": "MyContainer"
      }
    ]
  },
  "exports": {
    "MyContainer": { "type": "durable-object", "storage": "sqlite" }
  }
}
```

Key config requirements:
- `image` - Path to Dockerfile or directory containing Dockerfile
- `class_name` - Must match Container class export name
- `max_instances` - Max concurrent container instances
- Must configure a Durable Object binding and a SQLite lifecycle entry in `exports`

### Instance Types

#### Predefined Types

| Type | vCPU | Memory | Disk |
|------|------|--------|------|
| lite | 1/16 | 256 MiB | 2 GB |
| basic | 1/4 | 1 GiB | 4 GB |
| standard-1 | 1/2 | 4 GiB | 8 GB |
| standard-2 | 1 | 6 GiB | 12 GB |
| standard-3 | 2 | 8 GiB | 16 GB |
| standard-4 | 4 | 12 GiB | 20 GB |

```jsonc
{
  "containers": [
    {
      "class_name": "MyContainer",
      "image": "./Dockerfile",
      "instance_type": "standard-2"  // Use predefined type
    }
  ]
}
```

#### Custom Types (Jan 2026 Feature)

```jsonc
{
  "containers": [
    {
      "class_name": "MyContainer",
      "image": "./Dockerfile",
      "instance_type": {
        "vcpu": 2,              // 1-4 vCPU
        "memory_mib": 8192,     // 512-12288 MiB (up to 12 GiB)
        "disk_mb": 16000       // Check the current disk allocation limits
      }
    }
  ]
}
```

**Custom type constraints:**
- Minimum 3 GiB memory per vCPU
- Maximum 2 GB disk per 1 GiB memory
- Max 4 vCPU, 12 GiB memory, 20 GB disk per container

### Account Limits

| Resource | Limit | Notes |
|----------|-------|-------|
| Total memory (all containers) | 400 GiB | Across all running containers |
| Total vCPU (all containers) | 100 | Across all running containers |
| Total disk (all containers) | 2 TB | Across all running containers |
| Image storage per account | 50 GB | Stored container images |

### Container Class Properties

```typescript
import { Container } from "@cloudflare/containers";

export class MyContainer extends Container {
  // Port Configuration
  defaultPort = 8080;             // Default port for fetch() calls
  requiredPorts = [8080, 9090];   // Ports to wait for in startAndWaitForPorts()

  // Lifecycle
  sleepAfter = "30m";             // Inactivity timeout (5m, 30m, 2h, etc.)

  // Network
  enableInternet = true;          // Allow outbound internet access

  // Health Check
  pingEndpoint = "/health";       // Health check endpoint path

  // Environment
  envVars = {                     // Environment variables passed to container
    NODE_ENV: "production",
    LOG_LEVEL: "info"
  };

  // Startup
  entrypoint = ["/bin/start.sh"]; // Override image entrypoint (optional)
}
```

**Property details:**

- **`defaultPort`**: Port used when calling `container.fetch()` without explicit port. Falls back to port 33 if not set.

- **`requiredPorts`**: Array of ports that must be listening before `startAndWaitForPorts()` returns. The required-port list controls startup readiness; explicitly set defaultPort for fetch routing.

- **`sleepAfter`**: Duration string (e.g., "5m", "30m", "2h"). Container stops after this period of inactivity. Timer resets on each request.

- **`enableInternet`**: Boolean. If `true`, container can make outbound HTTP/TCP requests.

- **`pingEndpoint`**: Path used for health checks. Should respond with 2xx status.

- **`envVars`**: Object of environment variables. Merged with runtime-provided vars (see below).

- **`entrypoint`**: Array of strings. Overrides container image's CMD/ENTRYPOINT.

### Runtime Environment Variables

Cloudflare automatically provides these environment variables to containers:

| Variable | Description |
|----------|-------------|
| `CLOUDFLARE_APPLICATION_ID` | Worker application ID |
| `CLOUDFLARE_COUNTRY_A2` | Two-letter country code of request origin |
| `CLOUDFLARE_LOCATION` | Cloudflare data center location |
| `CLOUDFLARE_REGION` | Region identifier |
| `CLOUDFLARE_DURABLE_OBJECT_ID` | Container's Durable Object ID |

Custom `envVars` from Container class are merged with these. Custom vars override runtime vars if names conflict.

### Image Management

**Distribution model:** Image distribution and placement affect startup time. Measure the selected image; do not assume it is preloaded at every location.

**Rolling deploys:** Unlike Workers (instant), container deployments roll out gradually. Old versions continue running during rollout.

**Ephemeral disk:** Container disk is ephemeral and resets on each stop. Use Durable Object storage (`this.ctx.storage`) for persistence.

## wrangler.toml Format

```toml
name = "my-worker"
main = "src/index.ts"
compatibility_date = "2026-01-10"

[[containers]]
class_name = "MyContainer"
image = "./Dockerfile"
instance_type = "standard-2"
max_instances = 10

[[durable_objects.bindings]]
name = "MY_CONTAINER"
class_name = "MyContainer"

[exports.MyContainer]
type = "durable-object"
storage = "sqlite"
```

Both `wrangler.jsonc` and `wrangler.toml` are supported. Use `wrangler.jsonc` for comments and better IDE support. Existing migration-based deployments remain supported; keep their migration tags and do not combine Durable Object `migrations` with `exports`.

Verify current [instance types and limits](https://developers.cloudflare.com/containers/platform/limits/) before capacity changes. Custom types use `instance_type` with `vcpu`, `memory_mib`, and `disk_mb`; memory and disk units differ.
