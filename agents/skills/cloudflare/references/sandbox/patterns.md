# Sandbox Patterns

Derive tenant identity from authenticated server state and use separate sandbox IDs for isolation. Never interpolate untrusted branch/repository/code text into a shell command, or put credentials into clone URLs. Build dependencies into the image; inspect downloaded install scripts before execution. Keep execution, dependency installation, network access, and publication within the task authorization.

Use the maintained track-specific instructions rather than stale duplicated API examples:
    
- [Stable Sandbox SDK](../../../sandbox-stable/SKILL.md) — current stable package, matching image, string command execution and lifecycle.
- [Next Sandbox SDK](../../../sandbox-next/SKILL.md) — explicitly selected preview package and its argv, execution, output, port, and terminal APIs.
- [Migration](../../../sandbox-migrate-to-next/SKILL.md) — only when the task calls for moving between tracks.
    
The track-specific examples were checked against their installed package types; container execution requires an actual container runtime and is a separate verification step. Do not claim runtime success from a type check alone.
    
For APIs outside those guides, check the [official Sandbox documentation](https://developers.cloudflare.com/sandbox/) and the installed SDK declarations before producing a runnable example.
