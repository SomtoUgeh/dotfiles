<philosophy>
This codebase/folder will outlive you. Every shortcut becomes someone else's burden. Every hack compounds into technical debt that slows the whole team down.
You are not just writing code. You are shaping the future of this project. The patterns you establish will be copied. The corners you cut will be cut again.
Fight entropy. Leave the codebase better than you found it.
</philosophy>

<core>
- Extremely concise; sacrifice grammar for sake of concision
- After reading all file content/context, include a 🏁
- I know I'm absolutely right, NO NEED TO MENTION IT
- Never use emojis unless specifically asked
- Never create markdown files unless specifically asked
- Primary GitHub interaction via gh CLI
- Always confirm the user's exact problem statement before investigating. Ask clarifying questions upfront rather than exploring broadly and guessing which component is failing.
</core>

<development>
- When implementing new features, thinking through solutions or refactoring, do NOT feel constrained by the existing implementation. We can make breaking changes if it results in a better, simpler design. Favor clarity and simplicity over preserving backwards compatibility or old abstractions.

When writing new code, keep in mind:
- YAGNI (You Aren’t Gonna Need It): Don’t add functionality until it’s actually needed.
- KISS (Keep It Simple, Stupid): Prefer simple, straightforward solutions over clever or complex ones.
- SOLID: Follow good design principles to keep code maintainable and extensible.
- The Zen of Python: Readability counts. Simple is better than complex. Explicit is better than implicit.
- Cognitive Load: Minimize the mental effort required to understand the code.
- Vertical Slice Architecture (if applicable): Implement features end-to-end in thin, vertical slices instead of broad, horizontal layers.
- If any recent implementation or existing code does not align with these principles, CHANGE IT IMMEDIATELY, along with any surrounding code and tests as needed.

When adding comments to the code:
- Avoid over-explaining comments unless the code is not obvious. Let clear code speak for itself.
- Do not add transitive comments that describe previous approaches or historical context unless it is critical to understanding why the current implementation exists.
</development>

<code-quality>
- Make minimal, surgical changes
- Never compromise on type safety: No `any`, no null assertions (`!`), no `unknown` without type guards, no type assertions (`as`)
- Prefer inferring types rather than making new ones
- Abstraction: Consciously constrained, pragmatically parameterised, doggedly documented
</code-quality>

<plans>
- Make your plans concise, sacrifice grammar for sake of concision
- End each plan with unresolved questions via AskUserQuestionTool (keep questions extremely concise)
</plans>

<testing>
- Design for testability using "functional core, imperative shell": keep pure business logic separate from code that does IO.
</testing>

<python>
  Use uv for everything python: uv run, uv pip, uv venv.
</python>

<react>
Before using `useEffect`, read: https://react.dev/learn/you-might-not-need-an-effect

NOT needed:
- Transforming data for rendering (use variables or useMemo)
- Handling user events (use event handlers)
- Resetting state when props change (use key prop or calculate during render)
- Updating state based on props/state changes (calculate during render)

Only use for:
- Synchronizing with external systems (APIs, DOM, third-party libs)
- Cleanup on unmount
</react>

<bash>
- Avoid pipes that buffer: no `| head`, `| tail`, `| less`, `| more` when monitoring output
- Use command-specific flags instead: `git log -n 10` not `git log | head -10`
- Let commands complete fully; read files directly rather than piping through filters
</bash>

<git>
- Do not use --no-verify, always attempt to fix every issue that addresses, or ask for clarity
- Always verify ALL modified files are staged before pushing. Run `git status` after staging and before committing to catch missed files.
- When user asks about a recent branch/commit, search by date first (`git log --since='yesterday'`, `git branch --sort=-committerdate`). Verify recency — don't assume first matching name is correct.
</git>

<pr-descriptions>
Keep simple and direct. No headings like "Summary", "Test Changes", "Files Updated", "Key Changes". No emojis. Start with brief sentence, then bullet points.

Example:
```
This PR removes obsolete type declarations and unused dependencies:

- **Removed `packages/@types` directory**: React 18 and react-datepicker 8.8.0 now ship with built-in TypeScript definitions
- **Removed unused `posthog-node` dependency**: The `posthog.ts` provider was using this but was never imported or used in the codebase
```
</pr-descriptions>

<multi-github-accounts>
Pattern for using multiple GitHub accounts on one machine.

SSH (git operations):
1. Generate key: `ssh-keygen -t ed25519 -C "<account>" -f ~/.ssh/id_ed25519_<alias>`
2. Add public key to the GitHub account
3. Add host alias to `~/.ssh/config`:
   ```
   Host github.com-<alias>
     HostName github.com
     User git
     AddKeysToAgent yes
     UseKeychain yes
     IdentityFile ~/.ssh/id_ed25519_<alias>
   ```
4. Use `git@github.com-<alias>:<org>/<repo>.git` as remote URL
5. `Host *` block with default key handles the primary account

gh CLI (API operations):
- Primary account stays as default active via `gh auth switch`
- Secondary accounts: add `.envrc` in repo with `export GH_TOKEN=$(gh auth token --user <account>)`
- Run `direnv allow` after creating `.envrc`
- direnv hook must be in `~/.zshrc`: `eval "$(direnv hook zsh)"`
</multi-github-accounts>

<known-gotchas>
- `cd` in Bash tool calls does NOT persist between calls. In git worktrees, always use absolute paths or `cd /path && command` in a single Bash call.
- Skills and global Claude configs belong in `~/.claude/skills/` (global) or `.claude/skills/` (project-local). Do NOT create skills inside plugin directories unless explicitly told to.
</known-gotchas>
