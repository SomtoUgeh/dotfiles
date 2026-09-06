# Add a Workflow

Read [recommended structure](../references/recommended-structure.md) and [validation](../references/workflows-and-validation.md).

1. Resolve and read the target skill. Identify the requested intent and distinguish it from existing routes.
2. Keep a small skill inline when practical; add a router only if distinct procedures justify it. Preserve the existing behavior.
3. Write the workflow with required reading, prerequisites, ordered actions, failure handling, and observable completion criteria.
4. Add a direct entrypoint link and route from the user's intent. Do not require an intake answer when the request already selects the route.
5. Add only genuinely missing references or helpers; validate their external claims and compatibility.
6. Test the new route and a previously supported route, including missing input and unavailable-tool behavior where relevant.

Complete when both the new workflow and preserved workflows remain reachable and correct.
