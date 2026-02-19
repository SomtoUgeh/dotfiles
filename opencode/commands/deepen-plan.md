---
description: Enhance a plan with dynamic skill/agent discovery and targeted research
---

# Deepen Plan

Enhance an existing plan with dynamic skill/agent discovery and targeted research.

## Plan Folder

<plan_path> #$ARGUMENTS </plan_path>

**If empty:** Check `ls docs/plans/` and ask user which plan to deepen.

## Workflow

### 1. Load Plan

Read the plan folder contents:
- `spec.md` - Human-readable plan
- `prd.json` - Machine-executable stories
- `brainstorm.md` - Optional context

Parse and identify:
- Technologies mentioned (React, Next.js, Node.js, TypeScript, etc.)
- Domain areas (UI, API, data, auth, payments, etc.)
- Story categories from prd.json
- Keywords and triggers

### 2. Discover Available Skills

**Scan all skill paths:**

```bash
# User skills
find ~/.claude/skills -name "SKILL.md" 2>/dev/null

# Plugin skills
find ~/.claude/plugins/cache -name "SKILL.md" 2>/dev/null
find ~/.claude/plugins/marketplaces -name "SKILL.md" 2>/dev/null
```

**Extract skill metadata from each SKILL.md:**

```bash
for skill_file in $(find ~/.claude/skills ~/.claude/plugins -name "SKILL.md" 2>/dev/null); do
  # Extract frontmatter
  name=$(sed -n '/^---$/,/^---$/p' "$skill_file" | grep "^name:" | cut -d: -f2- | xargs)
  description=$(sed -n '/^---$/,/^---$/p' "$skill_file" | grep "^description:" | cut -d: -f2-)
  echo "SKILL|$name|$description"
done
```

**Build skill registry:**

| Skill | Triggers On |
|-------|-------------|
| (dynamically populated from SKILL.md descriptions) |

### 3. Discover Available Agents

**Scan agent paths:**

```bash
# User agents (organized by category)
find ~/.config/opencode/agents -name "*.md" 2>/dev/null

# Plugin agents  
find ~/.config/opencode/plugins -path "*/agents/*.md" 2>/dev/null
```

**Extract agent metadata from each .md file:**

```bash
for agent_file in $(find ~/.config/opencode/agents ~/.config/opencode/plugins -path "*/agents/*.md" 2>/dev/null); do
  # Extract frontmatter
  name=$(sed -n '/^---$/,/^---$/p' "$agent_file" | grep "^name:" | cut -d: -f2- | xargs)
  description=$(sed -n '/^---$/,/^---$/p' "$agent_file" | grep "^description:" | cut -d: -f2-)
  category=$(dirname "$agent_file" | xargs basename)
  echo "AGENT|$name|$category|$description"
done
```

**Agent paths:**
```
~/.config/opencode/agents/research/*.md    → research agents (4)
~/.config/opencode/agents/review/*.md      → review agents (6)
~/.config/opencode/agents/workflow/*.md    → workflow agents (1)
~/.config/opencode/plugins/**/agents/*.md  → plugin agents
```

**Build agent registry from discovery:**

| Agent | Category | Use When |
|-------|----------|----------|
| (dynamically populated from agent .md descriptions) |

### 4. Match Skills to Stories

For each story in prd.json:

```
For story in prd.stories:
  matched_skills = []
  matched_agents = []

  # Match by category
  if story.category == "ui":
    matched_skills += ["frontend-design", "emil-design-engineering", "web-design-guidelines"]

  if story.category == "performance":
    matched_agents += ["performance-oracle"]

  if story.category == "integration":
    matched_agents += ["security-sentinel", "silent-failure-hunter"]

  if story.category == "edge-case":
    matched_agents += ["silent-failure-hunter"]

  # Match by breadboard presence
  if spec_has_breadboard:
    matched_agents += ["breadboard-reflection"]

  # Match by keywords in title/acceptance_criteria
  keywords = extract_keywords(story.title + story.acceptance_criteria)

  for skill in discovered_skills:
    if skill.triggers_match(keywords):
      matched_skills.append(skill.name)

  # Match by tech stack (detected from spec.md)
  if "react" in tech_stack or "next" in tech_stack:
    matched_skills += ["vercel-react-best-practices"]
    if "component" in keywords:
      matched_skills += ["vercel-composition-patterns"]

  if "animation" in keywords or "transition" in keywords:
    matched_skills += ["web-animation-design"]

  if "stripe" in keywords or "payment" in keywords:
    matched_skills += ["stripe-best-practices"]
    matched_agents += ["security-sentinel"]

  if "form" in keywords or "input" in keywords:
    matched_skills += ["emil-design-engineering"]

  # Update story
  story.skills = dedupe(matched_skills)
  story.validation_agents = dedupe(matched_agents)
```

### 5. Apply Relevant Skills

For each unique skill matched to any story:

Load the matched skill using the **skill** tool to extract concrete recommendations for the plan.

### 5.5. Breadboard Validation (Conditional)

**Gate:** Only run if spec.md contains breadboard affordance tables (UI Affordances, Code Affordances).

**Validation checks:**

- [ ] Every UI affordance (U) has at least one prd.json story covering it
- [ ] Every Code affordance (N) is referenced or implied by a story
- [ ] Every prd.json story maps to at least one breadboard affordance
- [ ] **Flag gaps:** affordances with no story coverage (missing from plan)
- [ ] **Flag horizontal stories:** stories with no affordance mapping (story may be horizontal, not vertical)

**Output:** Add validation results to spec.md Enhancement Summary section.

**Also:** Add `breadboard-reflection` to the agent discovery registry so it can be matched to stories that reference breadboard affordances.

### 6. Query Framework Documentation

Use Context7 for frameworks/libraries detected:

```
mcp__plugin_context7_context7__resolve-library-id: Find ID for [framework]
mcp__plugin_context7_context7__query-docs: Query specific patterns
```

### 7. Run Targeted Review Agents

**Only run 2-3 agents most relevant to plan content.**

Select based on:
- Story categories (many ui → design agents, any security → security-sentinel)
- Risk level (payments, auth, data → security + architecture)
- Complexity (many stories → architecture-strategist)

```
Task [agent-name]: "Review this plan: [spec.md content]"
```

Run matched agents in parallel.

### 8. Enhance spec.md

For relevant sections, add:

```markdown
### Research Insights

**Best Practices:**
- [Concrete recommendation from skill/agent]

**Implementation Details:**
```typescript
// Code example from framework docs
```

**Edge Cases:**
- [Case and handling]

**References:**
- [URL from Context7 or agent research]
```

### 9. Update prd.json

Update each story with discovered skills and agents:

```json
{
  "id": 1,
  "title": "User can create account form",
  "category": "ui",
  "skills": ["frontend-design", "emil-design-engineering", "vercel-react-best-practices"],
  "validation_agents": ["code-simplicity-reviewer", "kieran-typescript-reviewer"],
  ...
}
```

### 10. Add Enhancement Summary

At top of spec.md:

```markdown
## Enhancement Summary

**Deepened:** YYYY-MM-DD
**Skills discovered:** [count] available, [count] matched
**Agents consulted:** [list]

### Key Improvements
1. [Improvement]
2. [Improvement]

### Skills Applied to Stories
| Story | Skills | Validation Agents |
|-------|--------|-------------------|
| #1 Create account form | frontend-design, emil-design-engineering | code-simplicity-reviewer |
```

### 11. Write Updates

- Update spec.md with research insights
- Update prd.json with skills and validation_agents

## Discovery Reference

### Skill Paths

```
~/.claude/skills/*/SKILL.md
~/.claude/plugins/cache/**/skills/*/SKILL.md
~/.claude/plugins/marketplaces/**/skills/*/SKILL.md
```

### Agent Paths

```
~/.config/opencode/agents/research/*.md      → research agents (4)
~/.config/opencode/agents/review/*.md        → review agents (6)
~/.config/opencode/agents/workflow/*.md      → workflow agents (1)
```

**Plugin agents include:**
- `pr-review-toolkit`: code-reviewer, silent-failure-hunter, code-simplifier, comment-analyzer, pr-test-analyzer, type-design-analyzer
- `feature-dev`: code-explorer, code-architect
- `plugin-dev`: agent-creator, skill-reviewer, plugin-validator
- `hookify`: conversation-analyzer

### Frontmatter Format (Skills & Agents)

```yaml
---
name: skill-or-agent-name
description: When to use this. Triggers on: keyword1, keyword2, ...
---
```

The `description` field contains trigger keywords - use these for matching.

### Category → Default Mappings

| Category | Default Skills | Default Agents |
|----------|----------------|----------------|
| `functional` | (tech-stack based) | `code-reviewer` |
| `ui` | `frontend-design`, `emil-design-engineering`, `web-design-guidelines` | `code-simplicity-reviewer` |
| `integration` | (service-specific) | `security-sentinel`, `silent-failure-hunter` |
| `edge-case` | - | `silent-failure-hunter` |
| `performance` | `vercel-react-best-practices` | `performance-oracle` |

### Tech Stack → Skill Mappings

| Tech Detected | Skills |
|---------------|--------|
| React, Next.js | `vercel-react-best-practices` |
| Component architecture | `vercel-composition-patterns` |
| Animation, transition, motion | `web-animation-design` |
| Stripe, payments | `stripe-best-practices` |
| Form, input, validation | `emil-design-engineering` |
| Browser automation | `agent-browser` |
| Code search, AST | `ast-grep` |

## Post-Enhancement Options

Ask user:

1. **View changes** - Show what was added to spec.md and prd.json
2. **Start `/workflows/work`** - Begin implementation
3. **Deepen specific story** - Run more research on one story
4. **Re-run discovery** - Scan for new skills/agents

NEVER CODE! Just research and enhance the plan.
