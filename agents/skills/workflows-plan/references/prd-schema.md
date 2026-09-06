# PRD schema and validation

**PRD Schema:**

```json
{
  "title": "feature-name",
  "ticket": "PROJ-1222",
  "branch": "feat/PROJ-1222-feature-name",
  "spec_path": "docs/plans/YYYY-MM-DD-<type>-<name>/spec.md",
  "created_at": "2026-01-30T12:00:00Z",
  "stories": [
    {
      "id": 1,
      "title": "User can create account",
      "category": "functional",
      "skills": [],
      "validation_agents": [],
      "depends_on": [],
      "acceptance_criteria": [
        "Given signup form, when valid data submitted, account is created",
        "Given signup form, when email exists, error message displays"
      ],
      "status": "pending",
      "priority": 10,
      "completed_at": null,
      "commit": null,
      "review_findings": []
    },
    {
      "id": 2,
      "title": "Account creation shows success feedback",
      "category": "ui",
      "skills": [],
      "validation_agents": [],
      "depends_on": [1],
      "acceptance_criteria": [
        "Given successful creation, when complete, success toast appears",
        "Given successful creation, when complete, user redirected to dashboard"
      ],
      "status": "pending",
      "priority": 20,
      "completed_at": null,
      "commit": null,
      "review_findings": []
    }
  ],
  "log": []
}
```

**Note:** `skills` and `validation_agents` are initially empty. Run `/workflows-deepen-plan` to:
1. Discover relevant skills through the active runtime's resolved catalog
2. Match skills to stories based on category, keywords, and tech stack
3. Assign validation agents for post-implementation review

**Field Reference:**

| Field | Type | Description |
|-------|------|-------------|
| `ticket` | string\|null | Ticket number (e.g., `PROJ-1222`), null if none |
| `branch` | string | Proposed Git branch: `type/[ticket]-description` or `type/description` |
| `id` | number | Unique integer, starts at 1 |
| `title` | string | One coherent, verifiable outcome |
| `category` | string | One of: functional, ui, integration, edge-case, performance |
| `skills` | array | Relevant skill names verified in the active catalog; invocation uses the current harness |
| `validation_agents` | array | Applicable review responsibilities or verified callable roles; recheck availability at execution |
| `depends_on` | array | Story IDs that must complete first |
| `acceptance_criteria` | array | Given/When/Then statements (min 1) |
| `status` | string | One of: pending, in_progress, blocked, completed |
| `priority` | number | Unique, spaced by 10 (10, 20, 30...) |
| `completed_at` | null\|string | ISO8601 timestamp when completed |
| `commit` | null\|string | Previously recorded implementation SHA, or null; a commit cannot contain its own SHA |
| `review_findings` | array | Findings from validation_agents or /workflows-review |

**Log Entry Shape (populated during /workflows-work):**

```json
{
  "timestamp": "2026-01-30T14:30:00Z",
  "story_id": 1,
  "action": "status_change",
  "from": "pending",
  "to": "in_progress",
  "agent": "active-agent"
}
```

**Review Finding Shape (populated by validation_agents or /workflows-review):**

```json
{
  "severity": "P1",
  "category": "security",
  "agent": "security-sentinel",
  "finding": "SQL injection risk in user input",
  "file": "src/api/users.ts:42",
  "suggestion": "Use parameterized queries",
  "status": "resolved",
  "resolved_at": "2026-01-30T15:00:00Z"
}
```

**Finding status values:**
- `logged` - Finding recorded, not yet addressed
- `resolved` - Finding fixed
- `wontfix` - Intentionally not fixing (with justification)

**PRD Generation Checklist:**

- [ ] `ticket` field set (or null if no ticket)
- [ ] `branch` field records the proposed implementation branch
- [ ] All acceptance criteria from spec are covered by stories
- [ ] Stories are ordered by dependency (blockers have lower priority numbers)
- [ ] No circular dependencies
- [ ] Initial skills is empty array (populated by /workflows-deepen-plan)
- [ ] Initial validation_agents is empty array (populated by /workflows-deepen-plan)
- [ ] Initial review_findings is empty array (populated by validation_agents or /workflows-review)
- [ ] Initial status is always "pending"
- [ ] Initial completed_at and commit are always null
- [ ] Initial log is always empty array
