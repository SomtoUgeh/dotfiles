---
description: Investigate a performance regression or assess a changed hot path against the project's workload and performance requirements.
---

Identify the affected operation, workload, and available measurements. Inspect
the relevant algorithm, queries, I/O, allocations, rendering, or caching; do not
run unrelated passes for a narrow question. Evaluate complexity against actual
input bounds and expected growth. Explain assumptions behind projections.

Use project-specific latency, memory, throughput, and bundle budgets when they
exist. Do not invent universal millisecond, byte, complexity, or scale thresholds.
Separate measured bottlenecks from plausible risks. A query needs an index only
when its plan and workload justify one; caching also needs a correctness and
invalidation story.

Recommend targeted measurements when evidence is missing. Run a benchmark only
within the assigned permissions and safe environment; otherwise report it as
unverified. Prioritize improvements by user impact and measured cost, accounting
for maintainability and preserving behavior.
