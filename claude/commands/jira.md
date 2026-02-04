---
name: jira
description: Create a Jira ticket interactively with proper formatting
argument-hint: "[optional: project key]"
---

# Create Jira Ticket

Create a well-structured Jira ticket using the official Atlassian CLI (acli).

## Workflow

### Step 1: Gather Information

Use AskUserQuestion to collect ticket details. If a project key was provided as argument, skip that question.

Questions to ask (batch into 1-2 AskUserQuestion calls):

1. **Project** (if not provided): Which project? Show available projects from `acli jira project list --limit 20`
2. **Type**: Task, Bug, Story, Epic, Sub-task
3. **Parent** (if Sub-task): Parent ticket key (e.g., PRE-123)
4. **Summary**: Brief title for the ticket
5. **Description**: Detailed description (offer to open editor for complex descriptions)
6. **Assignee** (optional): Email, @me, or default
7. **Labels** (optional): Comma-separated labels

### Step 2: Create the Ticket

Based on complexity:

**Simple ticket (short description):**
```bash
acli jira workitem create \
  --project "<PROJECT>" \
  --type "<TYPE>" \
  --summary "<SUMMARY>" \
  --description "<DESCRIPTION>" \
  --assignee "<ASSIGNEE>" \
  --label "<LABELS>" \
  --parent "<PARENT-KEY>"  # Only for Sub-tasks
```

**Complex ticket (long description with formatting):**
1. Write description to a temp file
2. Use `--from-file` or `--editor` flag

### Step 3: Confirm Creation

After creating, show the ticket key and offer to:
- Open in browser: `acli jira workitem view <KEY> --web`
- View details: `acli jira workitem view <KEY>`

## Notes

- Reference the jira skill for full command syntax
- For rich formatting (headings, lists, code blocks), use the ADF JSON template from `~/.claude/skills/jira/references/adf-template.json`
- Always confirm the ticket was created successfully before finishing
