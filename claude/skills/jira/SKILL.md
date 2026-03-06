---
name: jira
description: This skill provides workflows for managing Jira tickets using Atlassian's official CLI (acli). It should be used when creating, viewing, searching, or managing Jira work items from the command line. Triggers on "create jira ticket", "search jira", "view issue", "jira cli", "jira workitem".
---

# ACLI - Atlassian CLI for Jira

This skill enables efficient Jira ticket management using Atlassian's official `acli` command-line tool.

## Prerequisites

Verify acli is installed and authenticated:
```bash
which acli && acli jira auth status
```

## Core Commands

### Create Tickets

**Basic:**
```bash
acli jira workitem create \
  --project "<PROJECT_KEY>" \
  --type "<Task|Bug|Story|Epic>" \
  --summary "<title>"
```

**With details:**
```bash
acli jira workitem create \
  --project "<PROJECT_KEY>" \
  --type "<type>" \
  --summary "<title>" \
  --description "<description>" \
  --assignee "<email|@me|default>" \
  --label "<label1,label2>" \
  --parent "<PARENT-KEY>"  # Optional: for sub-tasks
```

**Interactive (opens editor):**
```bash
acli jira workitem create --project "<PROJECT_KEY>" --type "<type>" --editor
```

**From file (first line = summary, rest = description):**
```bash
acli jira workitem create --from-file "<path>" --project "<PROJECT_KEY>" --type "<type>"
```

**From JSON (for rich formatting + custom fields):**
```bash
acli jira workitem create --from-json "<path.json>"
```

### View Tickets

```bash
acli jira workitem view <KEY-123>                    # Basic
acli jira workitem view <KEY-123> --json             # JSON output
acli jira workitem view <KEY-123> --fields "*all"    # All fields
acli jira workitem view <KEY-123> --web              # Open browser
```

### Search Tickets (JQL)

```bash
acli jira workitem search --jql "<query>" --limit 20
acli jira workitem search --jql "<query>" --paginate    # All results
acli jira workitem search --jql "<query>" --json        # JSON output
acli jira workitem search --jql "<query>" --csv         # CSV output
acli jira workitem search --jql "<query>" --count       # Count only
```

**Common JQL patterns:**
- `project = PRE` - By project
- `assignee = currentUser()` - My tickets
- `status = "In Progress"` - By status
- `labels = urgent` - By label
- `created >= -7d` - Recent tickets
- `project = PRE AND status != Done ORDER BY priority DESC` - Combined

### Edit Tickets

```bash
acli jira workitem edit --key <KEY-123> --summary "<new title>"
acli jira workitem edit --key <KEY-123> --description "<new desc>"
acli jira workitem edit --key "<KEY-1,KEY-2>" --label "<labels>"  # Bulk
```

### Transitions

```bash
acli jira workitem transition --key <KEY-123> --status "In Progress"
acli jira workitem transition --key <KEY-123> --status "Done"
acli jira workitem transition --jql "<query>" --status "<status>"  # Bulk
```

### Assignments

```bash
acli jira workitem assign --key <KEY-123> --assignee "<email>"
acli jira workitem assign --key <KEY-123> --assignee "@me"
acli jira workitem assign --key <KEY-123> --assignee "default"
```

### Comments

```bash
acli jira workitem comment create --key <KEY-123> --body "<text>"
acli jira workitem comment list --key <KEY-123>
acli jira workitem comment update --key <KEY-123> --comment-id <id> --body "<text>"
acli jira workitem comment delete --key <KEY-123> --comment-id <id>
```

### Other Operations

```bash
acli jira workitem clone --key <KEY-123>
acli jira workitem link create --key <KEY-123> --link-key <KEY-456> --type "blocks"
acli jira workitem archive --key <KEY-123>
acli jira workitem delete --key <KEY-123>
```

### Projects

```bash
acli jira project list --limit 50
acli jira project view <PROJECT_KEY>
```

## JSON Template for Rich Tickets

For tickets requiring rich formatting (headings, lists, code blocks), use ADF (Atlassian Document Format). Reference `references/adf-template.json` for the full structure.

**Generate a template:**
```bash
acli jira workitem create --generate-json > ticket-template.json
```

## Workflow Patterns

### Create well-structured bug report
1. Gather: summary, steps to reproduce, expected vs actual behavior
2. Use `--editor` or `--from-json` for rich formatting
3. Add labels: `bug`, severity, component

### Bulk operations
1. First search with `--jql` to verify scope
2. Use comma-separated keys or `--jql` flag on edit/transition commands

### Quick ticket from terminal
```bash
acli jira workitem create -p PRE -t Task -s "Quick task" -a @me
```
