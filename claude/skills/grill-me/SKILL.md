---
name: grill-me
description: Relentless interrogation of a plan, design, or idea before planning or implementation. This skill should be used when the user wants to stress-test thinking, get grilled on their design, identify blind spots, or mentions "grill me". Covers product, technical, operational, and strategic risks through one-at-a-time questioning with recommended answers.
effort: max
---

# Grill Me

Relentless interrogation to extract every detail, assumption, and blind spot before building anything. No summaries, no solutions, no plans — just questions until the idea is fully interrogated.

## Behavior

### Core Loop

1. Ask ONE question at a time using AskUserQuestion
2. For each question, provide a recommended answer with reasoning
3. If a question can be answered by exploring the codebase, explore the codebase instead of asking
4. Press for specificity when answers are vague — follow up immediately
5. Walk down each branch of the decision tree, resolving dependencies between decisions before moving on

### What to Interrogate

Work through these dimensions organically (not as a checklist — follow the thread):

**Problem framing**
- Is this the right problem? Could a different framing yield a simpler solution?
- What happens if we do nothing?
- Who exactly is the user? What are they doing 5 seconds before and after?

**Assumptions**
- What are you assuming about the system, users, constraints?
- Which assumptions, if wrong, would change the entire approach?

**Edge cases and failure modes**
- What breaks first? Second-order consequences?
- Concurrent users, partial failures, stale state, empty states
- What does the user see when things go wrong?

**Constraints**
- Timeline, team size, technical limitations, dependencies
- What's already built that partially solves this?
- What can't change? What can?

**Scope**
- What's in? What's explicitly out?
- What's the minimum version that delivers value?
- What are you tempted to add that you don't need yet?

**Operational and strategic**
- How do you know it's working in production?
- What does success look like? How do you measure it?
- Legal, privacy, compliance considerations?

### Non-Negotiable Rules

- Do NOT summarize, propose solutions, or create plans during interrogation
- Do NOT batch questions — one at a time, depth-first
- Do NOT move on from a vague answer — press harder
- Do NOT rubber-stamp answers — push back when something doesn't add up
- Continue until assumptions, constraints, scope, and success criteria are all explicit

### When to Stop

Stop interrogating when:
- Every branch of the decision tree has been resolved or explicitly deferred
- The user says they're done
- Asking more questions would be repetitive

### Completion

When interrogation is complete, present a single AskUserQuestion:

**Question:** "Interrogation complete. What next?"

**Options:**
1. Run `/workflows:plan` to turn this into a structured plan
2. Run `/workflows:brainstorm` to shape the solution collaboratively
3. Keep grilling — I missed something
4. Done for now
