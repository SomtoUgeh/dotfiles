---
name: erivault-diagnostics
description: Diagnoses Erivault application behavior across product docs, repo code, Cloudflare, Neon Postgres, queues, Durable Objects, R2 assets, AI Gateway, media workflows, browser, and mobile capture state. Use when investigating Erivault bugs, asking "what happened", checking logs, verifying deploys, debugging capture evidence, or designing testable diagnostics.
---

# Erivault Diagnostics

Diagnose Erivault from product truth outward: docs, repo, runtime state, database, Cloudflare, and user-visible behavior.

- **IS:** investigating Erivault bugs, live incidents, capture/media issues, deploy verification, queue/workflow behavior, and diagnostic design.
- **IS NOT:** generic TDD guidance or broad exploratory QA. Use `tdd` for red-green-refactor implementation and `dogfood` for black-box browser issue discovery.

## Reference Files

| File | Read When |
|------|-----------|
| `references/access-and-docs.md` | Starting any Erivault investigation or needing Cloudflare, Neon, deploy, or repo access |
| `references/cloudflare-operations.md` | Inspecting Worker logs, queues, workflows, Durable Objects, R2, AI Gateway, or media transforms in local, dev, or prod |
| `references/runtime-surfaces.md` | Mapping which Erivault services, queues, databases, and UI surfaces are involved |
| `references/evidence-media-diagnostics.md` | Debugging capture, handoff, IndexedDB, uploads, evidence, R2, AI review, or media transforms |
| `references/output-template.md` | Reporting findings, verification, and remaining gaps |

## Workflow

Copy this checklist to track progress:

```text
Erivault diagnostics progress:
- [ ] Step 1: Restate the symptom and environment
- [ ] Step 2: Establish access and read the local docs
- [ ] Step 3: Map the product owner and runtime surfaces
- [ ] Step 4: Gather evidence from browser, DB, Cloudflare, and repo
- [ ] Step 5: Separate product bugs from diagnostic gaps
- [ ] Step 6: Fix or recommend the smallest complete change
- [ ] Step 7: Verify with commands, live proof, and explicit gaps
```

### Step 1: Restate The Symptom And Environment

Capture the exact user-facing issue before touching tools:
- URL, workspace ID, inspection ID, target ID, asset ID, handoff ID, request ID, or queue/workflow ID if available
- environment: local, dev, production, mobile, desktop, guest handoff, authenticated flow
- expected behavior and observed behavior
- whether the issue is reproduced now or only reported from a prior run
- what data loss, stale state, privacy, or user-blocking risk is present

Use absolute dates and times when logs or deploys are involved.

### Step 2: Establish Access And Read The Local Docs

Load `references/access-and-docs.md`.

Before designing a fix, read the relevant local source of truth:
- active repo `AGENTS.md`
- nearby `README.md`
- `docs/adr/` for ownership decisions
- product `spec.md` or implementation notes when present
- Alchemy or deployment code for live topology
- worker READMEs for queue, workflow, R2, and Durable Object wiring

Then confirm access:
- Cloudflare account and worker tail logs
- Cloudflare queues, workflows, R2, AI Gateway, and Durable Objects when relevant
- Neon Postgres using approved local env or MCP access
- GitHub branch, deploy status, and current commit
- browser or mobile device access for the reported flow

Do not print secrets, tokens, database URLs, private media URLs, or raw customer data.

If Cloudflare surfaces are involved, load `references/cloudflare-operations.md`.

### Step 3: Map Product Owner And Runtime Surfaces

Load `references/runtime-surfaces.md`.

Name the surface that owns durable truth. In Erivault this is usually product/domain state in the web app and Postgres, not the transport that carried the event.

For each involved surface, identify:
- product ID or correlation ID
- state before and after the operation
- expected transition
- where retries happen
- where terminal failure is stored
- what the user should see while work is pending

### Step 4: Gather Evidence

Gather evidence in this order:
1. Browser or mobile visible state, including refresh behavior when relevant.
2. Product read model or DB rows.
3. Cloudflare logs, queues, workflows, R2 metadata, AI Gateway logs, and worker output.
4. Repo code and tests for the exact path.
5. Inference only after direct evidence is exhausted.

Use the right tool for the surface:
- Neon MCP or a safe DB command for product rows.
- Cloudflare tail logs or dashboard surfaces for workers, queues, workflows, R2, and AI Gateway.
- Browser tools for real UI state, network behavior, and screenshots.
- Local repo search for code paths and tests.

### Step 5: Separate Product Bugs From Diagnostic Gaps

A product bug means the durable behavior is wrong. A diagnostic gap means the behavior cannot be confidently explained.

Examples:
- UI duplicate because IndexedDB local state and product evidence are not reconciled: product/UI bug.
- Evidence row attached but mobile needs refresh to see preview: query invalidation or polling bug.
- Worker did the work but only logs prove it: diagnostic gap.
- Queue retries forever with no user-visible terminal state: product and diagnostic bug.

Do not call something fixed if the proof only covers an adjacent surface.

### Step 6: Fix Or Recommend The Smallest Complete Change

Prefer fixes that improve the product model:
- one durable owner for evidence, verification status, and review outcome
- stable IDs such as `assetId`, `clientCaptureId`, `handoffId`, target ID, and workflow ID
- explicit statuses for pending, retrying, attached, needs attention, failed, and legacy unknown
- query or polling behavior that reconciles local state with durable product state
- structured logs and metrics that answer "what happened" without manual archaeology

If the fix touches capture/media, load `references/evidence-media-diagnostics.md`.

### Step 7: Verify And Report

Run the narrow checks that cover the changed boundary, then add live proof when the issue is live-only.

A complete closeout includes:
- commands run and results
- DB rows or read model evidence
- Cloudflare request IDs, queue/workflow state, or AI Gateway evidence
- browser/mobile proof where the user experienced the issue
- what remains not verified

Use `references/output-template.md`.

## Anti-Rationalizations

| Excuse | Rebuttal |
|--------|----------|
| "The logs say it worked." | Logs are not product truth. Check the DB row or read model that the UI uses. |
| "It works after refresh." | Refresh success can hide polling, cache, socket, or local-state reconciliation bugs. |
| "This is a Cloudflare issue." | Prove which worker, queue, workflow, R2 object, or Durable Object failed before blaming the platform. |
| "The database row looks fine." | If the user sees stale UI, inspect query invalidation, polling, local storage, and browser state too. |
| "We can debug from prod tail next time." | Add bounded metrics, status rows, or safe structured logs so the next failure has a repeatable path. |

## Gotchas

- Treat Alchemy as the live topology authority. Wrangler files may be generated or local support files.
- Keep Wrangler auth, Alchemy auth, and explicit Cloudflare tokens separate when access fails.
- Use `assetId` as durable media identity. Treat `handoffId` as capture correlation metadata, not product truth.
- Do not expose private evidence bytes or raw provider responses just to make debugging easier.
- For mobile capture, reconcile IndexedDB recovery state with durable product evidence before rendering both.
- For async work, avoid sleeps as proof. Poll a product status, workflow status, queue state, or DB row with a timeout.
- State "not verified" when the evidence stops at code, typecheck, logs, or local tests without a live smoke.

## Related Skills

- `cloudflare` and `workers-best-practices` for Cloudflare Workers, queues, workflows, R2, Durable Objects, and deployments
- `neon-postgres` and `postgres` for product-state queries and migration diagnostics
- `tanstack-query-best-practices` for cache, polling, invalidation, and stale UI behavior
- `tdd` for implementing fixes test-first
- `dogfood` for browser QA once a flow is ready for black-box exploration
