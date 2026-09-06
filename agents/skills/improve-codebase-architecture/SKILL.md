---
name: improve-codebase-architecture
description: Audit a codebase for architectural friction, present visual deepening opportunities, and explore a user-selected candidate.
disable-model-invocation: true
---

# Improve Codebase Architecture

Find refactors that turn shallow modules into deep ones and improve locality, leverage, testability, and navigation.

## Context

Read `CONTEXT.md` and relevant ADRs before analysis. Apply the vocabulary and principles from `codebase-design`, including module, interface, depth, seam, adapter, leverage, locality, and the deletion test. Preserve the project's domain terms.

## Explore

Inspect the codebase directly. When broad exploration would help and the active runtime permits delegation, use its explorer or subagent capability through [RUNTIME_TOOLS.md](../RUNTIME_TOOLS.md); otherwise continue in the main agent. Look for shallow interfaces, scattered knowledge, leaking seams, low-locality call patterns, and behavior that is difficult to test through a stable interface.

## Present Candidates

Write a self-contained HTML report to the operating system's temporary directory and tell the user its absolute path. Use Mermaid for graph-shaped relationships and HTML, CSS, or SVG for editorial comparisons. Each candidate should include involved files, the friction, a plain-language change, benefits, a before/after view, ADR conflicts, and a confidence rating. End with the strongest recommendation.

See [HTML-REPORT.md](HTML-REPORT.md) for the report scaffold and visual patterns. Do not propose detailed interfaces until the user selects a candidate.

## Explore the Selection

Use `grill-with-docs` when the selected design should be tested against the project's domain model and ADRs; use `grill-me` for a conversation-only design interrogation. Keep `CONTEXT.md` current as terminology changes, and offer an ADR only for a durable rejected premise that future reviews would otherwise repeat.
