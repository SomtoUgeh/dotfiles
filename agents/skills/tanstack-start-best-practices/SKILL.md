---
name: tanstack-start-best-practices
description: TanStack Start best practices for full-stack React applications. Server functions, middleware, SSR, authentication, and deployment patterns. Activate when building full-stack apps with TanStack Start.
---

# TanStack Start Best Practices

Selected guidelines for implementing TanStack Start patterns in full-stack React applications. These rules cover server functions, middleware, SSR, authentication, and deployment.

## When to Apply

- Creating server functions for data mutations
- Setting up middleware for auth/logging
- Configuring SSR and hydration
- Implementing authentication flows
- Handling errors across client/server boundary
- Organizing full-stack code
- Deploying to various platforms

## Available local rules

This package contains 13 rule files. Consult the official documentation for topics not covered here, matching the installed package version.

- [api-routes: Create Server Routes for External Consumers](rules/api-routes.md)
- [auth-route-protection: Protect Routes with beforeLoad](rules/auth-route-protection.md)
- [auth-session-management: Implement Secure Session Handling](rules/auth-session-management.md)
- [deploy-adapters: Configure the Host's Vite Plugin](rules/deploy-adapters.md)
- [env-functions: Use Environment Functions for Configuration](rules/env-functions.md)
- [err-server-errors: Handle Server Function Errors](rules/err-server-errors.md)
- [file-separation: Separate Server and Client Code](rules/file-separation.md)
- [mw-request-middleware: Use Request Middleware for Cross-Cutting Concerns](rules/mw-request-middleware.md)
- [sf-create-server-fn: Use createServerFn for Server-Side Logic](rules/sf-create-server-fn.md)
- [sf-input-validation: Always Validate Server Function Inputs](rules/sf-input-validation.md)
- [ssr-hydration-safety: Prevent Hydration Mismatches](rules/ssr-hydration-safety.md)
- [ssr-prerender: Configure Static Prerendering and CDN Caching](rules/ssr-prerender.md)
- [ssr-streaming: Implement Streaming SSR for Faster TTFB](rules/ssr-streaming.md)

## How to Use

Each rule file in the `rules/` directory contains:
1. **Explanation** — Why this pattern matters
2. **Bad Example** — Anti-pattern to avoid
3. **Good Example** — Recommended implementation
4. **Context** — When to apply or skip this rule

## Full Reference

See individual rule files in `rules/` directory for detailed guidance and code examples.
