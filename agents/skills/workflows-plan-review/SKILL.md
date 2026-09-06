---
name: workflows-plan-review
description: Stress-test an implementation plan before work begins. Use when the user asks for a plan review, scope challenge, feasibility review, or a more or less ambitious version of a plan.
---

# Review an implementation plan

Review only. Do not implement the plan or edit product code.

Use [RUNTIME_TOOLS.md](../RUNTIME_TOOLS.md) for available tools and reviewer
roles. Shared authority, delegation, model, Git, and review policy in
`agents/shared/AGENTS.md` is authoritative.

## Inputs

Resolve the plan from the user's message, a named file, or the active
conversation. A plan may be a single document, several linked documents, or a
specification plus structured work items. Read every document the plan declares
as normative.

If no plan or objective can be identified, ask one focused question. Otherwise,
begin with the available evidence. Do not make the user repeat context already
present in the conversation or repository.

## Review stance

Use the user's requested mode when supplied:

| Mode | Review goal |
|---|---|
| EXPAND | Identify a materially better outcome that justifies more scope |
| SELECTIVE | Preserve scope and offer only high-value additions |
| HOLD | Test the plan rigorously without changing its intended scope |
| REDUCE | Find the smallest complete solution that still meets the objective |

Default to **HOLD**. A scope change is a recommendation. Explain the tradeoff
and ask before rewriting the plan around it.

## Evidence pass

Before judging the plan:

1. Identify its objective, constraints, acceptance criteria, affected systems,
   rollout boundary, and unresolved decisions.
2. Inspect the repository instructions and the smallest relevant set of code,
   tests, configuration, and history.
3. Check authoritative documentation when behavior depends on a framework,
   external API, or current platform rules.
4. Distinguish confirmed repository facts, plan statements, assumptions, and
   unknowns. Do not present an unverified claim as current fact.

Use bounded parallel research only for independent questions. Select callable
reviewers whose specialties match the change, normally no more than three.
Follow the shared model and harness rules; do not require a named model version.
An outside-model second opinion is opt-in. Use it only when the user requested
one and the runtime exposes a verified distinct model.

## Review axes

Apply the axes that matter to this plan:

- **Problem fit:** Does the work produce the requested user or business outcome?
- **Reuse and boundaries:** Does it follow existing code and ownership patterns?
- **Behavior:** Are normal, empty, loading, partial, retry, cancellation, and
  failure paths defined where relevant?
- **Data:** Are schemas, invariants, migrations, concurrency, idempotency,
  retention, and rollback addressed where relevant?
- **Interfaces:** Are API, event, command, and UI contracts explicit enough to
  implement and test?
- **Security and privacy:** Are trust boundaries, permissions, inputs, secrets,
  and sensitive outputs handled in proportion to risk?
- **Performance and operations:** Are realistic limits, observability, rollout,
  compatibility, and recovery covered where the change needs them?
- **Execution:** Are stories ordered by dependency, independently verifiable,
  and small enough to finish without hidden coordination?
- **Validation:** Do acceptance checks prove behavior rather than mirror the
  implementation? Are expensive test layers reserved for real risk?

Do not require a threat model, diagram, benchmark, migration, feature flag, or
observability work when the plan does not create that risk. Add them when the
evidence shows they are needed.

## Failure analysis

For each important flow, ask:

1. What can fail before, during, and after the state change?
2. What does the user observe?
3. What state remains, and can retry duplicate or corrupt work?
4. How is the failure detected and recovered?

Use a compact failure table only when it clarifies several distinct cases:

| Trigger | Resulting state | User impact | Detection | Recovery | Plan gap |
|---|---|---|---|---|---|

Use Mermaid or a small text diagram only when sequence, state, or ownership is
otherwise hard to assess. A diagram is evidence support, not a required
deliverable.

## Findings

Verify every proposed blocker against the plan and repository before reporting
it. Rank findings by practical impact:

- **P0:** unsafe to proceed; likely catastrophic loss, exposure, or outage
- **P1:** likely correctness, security, or delivery failure that must be fixed
- **P2:** material improvement with a concrete failure or maintenance cost
- **P3:** optional polish or future consideration

Each finding must include:

- the exact plan section or repository evidence;
- the trigger and observable consequence;
- why the current plan does not handle it; and
- the smallest concrete plan change that closes the gap.

Do not inflate severity for style preferences or speculative possibilities.
Combine duplicate findings. If evidence disproves a concern, remove it.

## Output

Return the review in the conversation by default:

1. **Verdict:** ready, ready with changes, or needs revision.
2. **Confirmed strengths:** only details that affect feasibility or reduce risk.
3. **Findings:** P0 through P3, with evidence and proposed corrections.
4. **Scope options:** only when EXPAND, SELECTIVE, or REDUCE changes the answer.
5. **Unresolved decisions:** questions that must be answered before implementation.
6. **Validation check:** whether the revised acceptance strategy proves the goal.

Do not create or update `spec.md`, `prd.json`, todo files, branches, commits,
pull requests, or external comments unless the user explicitly asked for that
specific action. If the user asks to revise plan files, apply accepted changes
only, preserve unrelated content, and report the exact files changed.

Stop after two review cycles surface the same unresolved concern. State the
remaining decision and the evidence needed to resolve it instead of repeating
the review.
