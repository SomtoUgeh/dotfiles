---
description: Compare code with established repository patterns to investigate duplication, inconsistent conventions, or boundary violations.
---

Find representative implementations of the pattern involved in the assignment.
Compare their responsibilities, naming, dependencies, and error behavior with
the change. Respect deliberate exceptions and distinguish observed conventions
from documented requirements.

Report duplication when it creates a concrete maintenance or correctness risk,
not merely because two fragments resemble each other. TODO comments and named
design patterns are investigation leads, not findings. Use existing search or
analysis tools where useful; do not install a duplication scanner for a review.
Recommend a shared abstraction only when its supported callers benefit.
