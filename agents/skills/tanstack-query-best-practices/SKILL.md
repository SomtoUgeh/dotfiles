---
name: tanstack-query-best-practices
description: TanStack Query (React Query) best practices for data fetching, caching, mutations, and server state management. Activate when building data-driven React applications with server state.
---

# TanStack Query Best Practices

Selected guidelines for implementing TanStack Query (React Query) patterns in React applications. These rules optimize data fetching, caching, mutations, and server state synchronization.

## When to Apply

- Creating new data fetching logic
- Setting up query configurations
- Implementing mutations and optimistic updates
- Configuring caching strategies
- Integrating with SSR/SSG
- Refactoring existing data fetching code

## Available local rules

This package contains 21 rule files. Consult the official documentation for topics not covered here, matching the installed package version.

- [cache-gc-time: Configure gcTime for Inactive Query Retention](rules/cache-gc-time.md)
- [cache-invalidation: Use Targeted Invalidation Over Broad Patterns](rules/cache-invalidation.md)
- [cache-placeholder-vs-initial: Understand Placeholder vs Initial Data](rules/cache-placeholder-vs-initial.md)
- [cache-stale-time: Set Appropriate staleTime Based on Data Volatility](rules/cache-stale-time.md)
- [err-error-boundaries: Use Error Boundaries with useQueryErrorResetBoundary](rules/err-error-boundaries.md)
- [inf-page-params: Always Provide getNextPageParam for Infinite Queries](rules/inf-page-params.md)
- [mut-invalidate-queries: Always Invalidate Related Queries After Mutations](rules/mut-invalidate-queries.md)
- [mut-mutation-state: Use useMutationState for Cross-Component Mutation Tracking](rules/mut-mutation-state.md)
- [mut-optimistic-updates: Implement Optimistic Updates for Responsive UI](rules/mut-optimistic-updates.md)
- [network-mode: Configure Network Mode for Offline Support](rules/network-mode.md)
- [parallel-use-queries: Use useQueries for Dynamic Parallel Queries](rules/parallel-use-queries.md)
- [perf-select-transform: Use Select to Transform and Filter Data](rules/perf-select-transform.md)
- [persist-queries: Configure Query Persistence for Offline Support](rules/persist-queries.md)
- [pf-intent-prefetch: Prefetch on User Intent (Hover, Focus)](rules/pf-intent-prefetch.md)
- [qk-array-structure: Always Use Arrays for Query Keys](rules/qk-array-structure.md)
- [qk-factory-pattern: Use Query Key Factories for Complex Applications](rules/qk-factory-pattern.md)
- [qk-hierarchical-organization: Organize Keys Hierarchically](rules/qk-hierarchical-organization.md)
- [qk-include-dependencies: Include All Variables the Query Depends On](rules/qk-include-dependencies.md)
- [qk-serializable: Ensure All Key Parts Are JSON-Serializable](rules/qk-serializable.md)
- [query-cancellation: Implement Query Cancellation Properly](rules/query-cancellation.md)
- [ssr-dehydration: Use Dehydrate/Hydrate Pattern for SSR](rules/ssr-dehydration.md)

## How to Use

Each rule file in the `rules/` directory contains:
1. **Explanation** — Why this pattern matters
2. **Bad Example** — Anti-pattern to avoid
3. **Good Example** — Recommended implementation
4. **Context** — When to apply or skip this rule

## Full Reference

See individual rule files in `rules/` directory for detailed guidance and code examples.
