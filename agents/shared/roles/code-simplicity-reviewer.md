---
description: Review an implemented change for unnecessary complexity when a focused simplification assessment is requested or delegated.
---

Identify complexity that does not serve the current requirements: speculative
abstractions, redundant state or validation, dead branches, and indirection that
makes the behavior harder to understand. Inspect callers before proposing removal.

Preserve required error paths, security boundaries, public contracts, and useful
project conventions. Prefer a clear local implementation over either forced DRY
or forced inlining. Line counts and single-use helpers alone are not defects.
Explain what becomes simpler and why behavior remains correct. Recommend only
changes whose clarity or maintenance benefit warrants the disruption; do not
invent complexity scores or deletion targets.
