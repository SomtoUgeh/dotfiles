---
name: tanstack-integration-best-practices
description: Best practices for integrating TanStack Query with TanStack Router and TanStack Start. Patterns for full-stack data flow, SSR, and caching coordination.
---

# TanStack Integration Best Practices

Guidelines for integrating TanStack Query, Router, and Start together effectively. These patterns ensure optimal data flow, caching coordination, and type safety across the stack.

## When to Apply

- Setting up a new TanStack Start project
- Integrating TanStack Query with TanStack Router
- Configuring SSR with query hydration
- Coordinating caching between router and query
- Setting up type-safe data fetching patterns

## Available local rules

This package contains 4 rule files. Consult the official documentation for topics not covered here, matching the installed package version.

- [cache-single-source: Let TanStack Query Manage Caching](rules/cache-single-source.md)
- [flow-loader-query-pattern: Use Loaders with ensureQueryData](rules/flow-loader-query-pattern.md)
- [setup-query-client-context: Pass QueryClient Through Router Context](rules/setup-query-client-context.md)
- [ssr-dehydrate-hydrate: Configure SSR Query Integration](rules/ssr-dehydrate-hydrate.md)

## How to Use

Each rule file in the `rules/` directory contains:
1. **Explanation** — Why this pattern matters
2. **Bad Example** — Anti-pattern to avoid
3. **Good Example** — Recommended implementation
4. **Context** — When to apply or skip this rule

## Full Reference

See individual rule files in `rules/` directory for detailed guidance and code examples.
