---
name: tanstack-router-best-practices
description: "Implement or review TanStack Router type-safe routes, loaders, search parameters, and navigation."
---

# TanStack Router Best Practices

Selected guidelines for implementing TanStack Router patterns in React applications. These rules optimize type safety, data loading, navigation, and code organization.

## When to Apply

- Setting up application routing
- Creating new routes and layouts
- Implementing search parameter handling
- Configuring data loaders
- Setting up code splitting
- Integrating with TanStack Query
- Refactoring navigation patterns

## Available local rules

This package contains 15 rule files. Consult the official documentation for topics not covered here, matching the installed package version.

- [ctx-root-context: Define Context at Root Route](rules/ctx-root-context.md)
- [err-not-found: Handle Not-Found Routes Properly](rules/err-not-found.md)
- [load-ensure-query-data: Use ensureQueryData with TanStack Query](rules/load-ensure-query-data.md)
- [load-parallel: Leverage Parallel Route Loading](rules/load-parallel.md)
- [load-use-loaders: Use Route Loaders for Data Fetching](rules/load-use-loaders.md)
- [nav-link-component: Prefer Link Component for Navigation](rules/nav-link-component.md)
- [nav-route-masks: Use Route Masks for Modal URLs](rules/nav-route-masks.md)
- [org-virtual-routes: Understand Virtual File Routes](rules/org-virtual-routes.md)
- [preload-intent: Enable Intent-Based Preloading](rules/preload-intent.md)
- [router-default-options: Configure Router Default Options](rules/router-default-options.md)
- [search-custom-serializer: Configure Custom Search Param Serializers](rules/search-custom-serializer.md)
- [search-validation: Always Validate Search Params](rules/search-validation.md)
- [split-lazy-routes: Use .lazy.tsx for Code Splitting](rules/split-lazy-routes.md)
- [ts-register-router: Register Router Type for Global Inference](rules/ts-register-router.md)
- [ts-use-from-param: Use `from` Parameter for Type Narrowing](rules/ts-use-from-param.md)

## How to Use

Each rule file in the `rules/` directory contains:
1. **Explanation** — Why this pattern matters
2. **Bad Example** — Anti-pattern to avoid
3. **Good Example** — Recommended implementation
4. **Context** — When to apply or skip this rule

## Full Reference

See individual rule files in `rules/` directory for detailed guidance and code examples.
