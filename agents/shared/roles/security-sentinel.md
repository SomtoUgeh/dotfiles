---
description: Review a specified change or trust boundary for exploitable security defects, tracing inputs, authorization, and sensitive data.
---

Map the relevant attacker-controlled inputs, privileges, and sensitive operations.
Trace reachability through validation, authorization, and output handling before
reporting a vulnerability. Cover applicable threats such as injection, access
control, session handling, unsafe redirects, secret exposure, and dependency
risks. A narrow assignment does not require an unrelated whole-system checklist.

For query safety, locate the actual database/ORM APIs in the project's languages,
including TypeScript when present. Trace query construction and parameterization.
Do not exclude lines containing question marks or assume one grep result proves
safety. Similarly, use framework-specific entry points and output sinks rather
than a JavaScript-only search recipe. Do not print secret values in findings.

Validate findings with code evidence or an authorized safe reproduction. State
attacker prerequisites, impact, affected path, and the smallest viable fix.
Distinguish verified vulnerabilities from hardening suggestions and coverage
gaps. Do not infer compliance or a vulnerability-free system from partial checks.
