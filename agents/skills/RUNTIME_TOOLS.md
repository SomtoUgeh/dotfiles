# Runtime Tool Equivalents

Use this mapping when a shared skill needs user input, progress tracking, subagents, or another skill. Prefer the active runtime's native tool name; if a tool is unavailable, use the fallback behavior described here.

| Capability | Claude | Codex | OpenCode | Fallback |
| --- | --- | --- | --- | --- |
| Ask the user for a decision | `AskUserQuestion` | `request_user_input` when available; otherwise ask directly in chat | `question` | Ask one concise question in chat and wait |
| Track todos or progress | `TodoWrite` | `update_plan` | `todowrite` / `todoread` | Keep a short checklist in the response or plan file |
| Launch a subagent | `Agent` | `spawn_agent` | `task` | Do the work locally and keep output concise |
| Load another skill | `Skill` | `$skill-name` or the active skill loader | `skill` | Read that skill's `SKILL.md` directly |

Runtime permissions belong in each app's config, not in shared `SKILL.md` frontmatter.
