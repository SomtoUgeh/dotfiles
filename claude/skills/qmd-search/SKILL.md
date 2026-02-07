---
name: qmd-search
description: qmd - Search local markdown notes, documentation, and Claude session history. Use when user says "qmd", "search notes", "find docs", "search sessions", "local search", "knowledge base search", or needs to retrieve markdown files.
allowed-tools:
  - Bash
  - Read
---

# qmd - Quick Markdown Search

Fast local search engine for markdown notes, documentation, and Claude session history.

## Quick Start

```bash
# Keyword search (instant, preferred)
qmd search "authentication flow"

# Get full document
qmd get "path/to/file.md"

# Search specific collection
qmd search "react hooks" -c claude-sessions
```

## Search Modes

### `qmd search` (Default - Use This)

BM25 keyword matching. Instant results.

```bash
qmd search "error handling"
qmd search "typescript generics" -n 10
qmd search "api design" --json
```

### `qmd vsearch` (Use Sparingly)

Vector similarity search. Slower - loads local models on each run.

```bash
qmd vsearch "concepts similar to dependency injection"
```

### `qmd query` (Avoid)

Hybrid search with LLM reranking. Slowest, often less reliable.

## Common Commands

### Search

```bash
qmd search "query"                    # default keyword search
qmd search "query" -n 10              # more results
qmd search "query" -c collection      # specific collection
qmd search "query" --json             # JSON output
qmd search "query" --files            # file paths only
qmd search "query" --full             # full document content
qmd search "query" --all --min-score 0.3  # all matches above threshold
```

### Retrieve Documents

```bash
qmd get "path/to/file.md"             # full document
qmd get "path/to/file.md:50"          # from line 50
qmd get "path/to/file.md" -l 100      # max 100 lines
qmd multi-get "journals/2025-01*.md"  # glob pattern
qmd multi-get "doc1.md, doc2.md"      # multiple files
```

### Collections

```bash
qmd collection list                   # show all collections
qmd collection add /path --name notes --mask "**/*.md"
qmd ls                                # list files in collections
qmd ls collection-name                # list files in specific collection
```

### Maintenance

```bash
qmd status                            # index health
qmd update                            # re-index changed files
qmd embed                             # update vector embeddings
```

## Output Formats

| Flag | Description |
|------|-------------|
| `--json` | JSON with snippets |
| `--files` | docid, score, filepath, context |
| `--csv` | CSV output |
| `--md` | Markdown output |
| `--xml` | XML output |
| `--full` | Complete document content |

## Search Options

| Option | Description |
|--------|-------------|
| `-n <num>` | Number of results (default: 5) |
| `-c, --collection <name>` | Filter to collection |
| `--all` | Return all matches |
| `--min-score <num>` | Minimum similarity score |
| `--line-numbers` | Add line numbers |

## Guidelines

- **Prefer `qmd search`** - instant BM25 keyword matching
- **Use `qmd vsearch` sparingly** - slow due to model loading
- **Avoid `qmd query`** - hybrid search often unreliable
- Use `--json` or `--files` for agent-friendly output
- Use `-c collection` to narrow scope when you know the target

Index location: `~/.cache/qmd/index.sqlite`
