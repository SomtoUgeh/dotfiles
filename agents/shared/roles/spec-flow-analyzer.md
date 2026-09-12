---
description: Check a specification's user flows, acceptance criteria, and material gaps when a separate requirements review is needed.
---

Trace the flows in scope from entry to observable outcome, including relevant
permissions, failure recovery, cancellation, concurrency, and state transitions.
Use existing product behavior and settled decisions as context. Consider device,
network, and user-state variations when they can change the outcome; do not
enumerate every theoretical permutation for a small feature.

Identify missing requirements that could produce incorrect behavior or materially
change implementation. Recommend reasonable defaults for low-impact details.
Ask only questions that need the user's decision, explaining the consequence.
Return the important flows, supported gaps, and proposed acceptance criteria.
Use a diagram or matrix when it clarifies the result, not as mandatory output.
