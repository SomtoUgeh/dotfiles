# Skill Authoring Best Practices

Use [core-principles.md](core-principles.md) and the [shared format contract](official-spec.md) as the maintained rules.

## Write for use

- Give a concrete trigger and an observable result.
- Use short, action-oriented headings and one term for each domain concept.
- Prefer a maintained default with explicit conditions for alternatives.
- Separate required behavior from suggestions; avoid unsupported universal rules.
- Keep instructions proportional to the task. An informational question should not automatically install tools, create files, or open a new task.
- Label sample data and hypothetical paths. Never present invented metrics, sources, or test outcomes as real.

## Keep examples usable

Include imports, setup, version constraints, and relevant error paths when an example is meant to run. Label partial snippets as fragments. Verify against released dependencies and the project's actual runtime. Link directly to primary sources for fragile external contracts.

## Evaluate

Test discovery, route selection, resource loading, expected output, and failure behavior. Use representative scenarios with explicit expected outcomes. Test each supported harness/model when available, and record missing coverage rather than inferring it. Use [iteration-and-testing.md](iteration-and-testing.md) for the procedure.
