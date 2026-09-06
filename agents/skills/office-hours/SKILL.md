---
name: office-hours
description: Run an explicit pre-build product diagnostic to test demand, users, scope, and premises before solution shaping. Use when the user asks for office hours, asks whether an idea is worth building, or requests a hard product critique.
---

# Office Hours

Challenge whether and what to build before solution shaping. This skill produces a product decision and, when requested, a design document. If the user asks to implement an idea, do not activate this diagnostic merely because they mention having an idea.

Use active runtime capabilities from [RUNTIME_TOOLS.md](../RUNTIME_TOOLS.md). Continue in the main agent when delegation, structured questions, visual output, or model selection is unavailable.

## Choose the Mode

Ask for the user's goal only when it is not already clear:

- **Startup mode:** demand, willingness to pay, current workaround, narrow wedge, and evidence.
- **Builder mode:** learning, craft, fun, demo value, and a satisfying achievable scope.

Structured question tools may support only two or three choices. Split larger sets across turns or ask a short free-form question. Ask one decision at a time.

## Operating Posture

Take a position and state what evidence would change it. Name a failure pattern when the evidence supports it, explain the consequence, and let the user answer. Do not turn bluntness into performance or repeat a challenge after the user has acknowledged the tradeoff.

Common patterns:

| Pattern | Evidence |
| --- | --- |
| Solution-first | The proposed implementation is clearer than the problem |
| Build-and-they-will-come | Demand is asserted without observed behavior |
| Boiling the ocean | The first release solves many unrelated jobs |
| Vitamin | The user loses little by keeping the status quo |
| Proxy problem | The idea treats a symptom while the blocking workflow remains |
| Premature platform | Infrastructure precedes a proven concrete use |
| Feature, not product | An incumbent can absorb the complete value cheaply |
| Audience of one | Only the builder needs it; valid when consciously chosen |

Startup stop criteria and signal scoring live in [references/diagnostic.md](references/diagnostic.md). Read it for startup-mode verdicts.

## Context

Use what the user already supplied. In a repository, read the active agent instructions, relevant product or architecture docs, and prior design documents before repeating questions. Search with repository-native tools such as `rg`.

Use an explorer only when the runtime permits it and repository discovery is broad enough to justify delegation. Give it a bounded read-only question.

If a related design exists, summarize the relevant prior decisions and ask whether they remain valid. Do not force the user through already-answered prompts.

## Diagnostic Conversation

In startup mode, establish:

1. the exact person with the problem;
2. observed demand or behavior;
3. the current workaround and its real cost;
4. the smallest outcome someone would pay for;
5. the narrowest testable wedge;
6. what would falsify the premise.

In builder mode, establish:

1. what makes the project worth doing for this builder;
2. the one moment that should feel impressive or satisfying;
3. time, skill, platform, and sharing constraints;
4. the smallest complete version.

Ask only questions whose answers can change the recommendation. Push back on vague categories by requesting one concrete person, workflow, example, or observation.

## Premise Challenge

State the strongest argument against the idea. Extract the load-bearing premises and label each as confirmed, assumed, or contradicted. Let the user correct missing context before changing direction.

For time-sensitive market or competitor claims, use current primary sources and separate facts from inference. Research only the claims that affect the decision.

## Alternatives

Offer two or three materially different approaches:

- a minimal experiment with the fewest moving parts;
- the strongest complete product direction;
- optionally, a lateral alternative that tests the problem without building the proposed solution.

Compare time, risk, learning value, and evidence gained. Recommend one. The user chooses the direction.

For a UI idea, a rough flow or layout sketch is optional when it exposes a real gap. Use an available visualization or diagram capability; do not depend on a named skill that is absent. Keep it to the few screens needed to show the primary flow.

## Verdict and Assignment

Use one verdict:

- **Proceed**
- **Proceed with caution**
- **Pause and gather evidence**
- **Stop this approach**

The verdict must follow the evidence. In startup mode, always give one concrete real-world assignment that tests demand, names the people or behavior to observe, and has a timeframe. Do not use “go build it” as the demand test. In builder mode, optimize the next step for the user's stated goal.

## Output

Present the result inline by default. Create `docs/plans/YYYY-MM-DD-<type>-<name>/design.md` only when the user requested a document or the repository's active workflow explicitly requires it. Read [references/document-and-review.md](references/document-and-review.md) for the document schema and review loop.

## Optional Independent Opinion

Offer another model's opinion only when it would add useful independent judgment. Use the runtime's native, explicit model-selection mechanism with a model distinct from the current one, and only after the user opts in. Keep context in tool input or a securely managed temporary file, delete any temporary file in a guaranteed cleanup path, and never claim model independence without explicit selection.

Present the other model's evidence and disagreement. Agreement alone does not authorize a direction change; explain the missing context and let the user decide.

## Handoff

If the verdict is Proceed, offer the project's shaping or planning workflow. If it is Pause or Stop, lead with the evidence-gathering assignment or reframing choice. Preserve the user's right to proceed after the tradeoff is clear.
