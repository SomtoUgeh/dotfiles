# Runtime Tool Equivalents

Shared skills describe capabilities. Use the active session's tool schemas and
permissions to select the implementation; the names below are examples, not a
promise that a particular version exposes them. A missing example tool is not
a reason to stop work when the fallback can complete it.

| Capability | Claude Code | Codex | OpenCode | Grok | Fallback |
| --- | --- | --- | --- | --- | --- |
| Ask a necessary question | `AskUserQuestion` | `request_user_input_async`, or `request_user_input` in its supported mode | `question` | Exposed question tool | Ask concisely in chat; continue independent work |
| Track progress | `TodoWrite` | `update_plan` when exposed | `todowrite` / `todoread` | Exposed todo/plan tool | Maintain a short in-context checklist; no unsolicited file |
| Launch a worker | `Agent` | `spawn_agent` / collaboration tools | `task` | `spawn_subagent` when exposed | Work locally; disclose when independence could not be provided |
| Read a skill | `Skill` or `/skill-name` | `$skill-name` or skill loader | `skill` | `/skill-name` or skill loader | Read the discovered `SKILL.md` and resolve references from its real directory |
| Read official web docs | `WebFetch` / search tools | Docs MCP / web tools | `webfetch` / search tools | Exposed web search/fetch | Use an available read-only HTTP client; report inaccessible sources |
| Interact with a browser | Available browser tool/CLI | Native browser or installed browser tool | Available browser tool/CLI | Available browser tool/CLI | Use installed `agent-browser` if appropriate; otherwise report the specific unverified interaction |
| Generate an image | Available image tool | Native image-generation tool | Available image tool | Available image tool | Provide a clearly labelled prompt/specification; do not claim an image was generated |

## Applying the mapping

- The user's named tool takes precedence. Check the installed CLI's help or
  tool schema before using version-specific arguments. Never install a CLI or
  dependency merely to satisfy an informational request.
- Respect question limits and mode restrictions. Split optional choices or use
  free text when needed. A tool's presence does not mean its current mode allows
  it. Authorization comes from the user/session, not from a skill's questionnaire.
- Check callable agent roles before choosing one. A role name in a skill is a
  responsibility, not permission to invent `subagent_type` or model parameters.
  Give independent workers explicit scope and ownership; respect dependency
  order and concurrency limits. Work locally when delegation is unavailable.
- Progress tools need not support custom IDs, metadata, or dependency graphs.
  Keep that reasoning in context and use only fields their schemas accept.
- `$ARGUMENTS` in an imported example means the user's actual invocation text;
  it is not an environment variable to pass literally into a shell.
- Choose one owner for each overlapping capability. Follow explicit
  user/project choice, otherwise use the owners below. Complementary skills
  can work together; do not load duplicate copies or combine competing styles.
- Runtime permissions and model configuration belong in each app's config.
  Shared role guidance lives in `agents/shared/AGENTS.md`. Verify an actual
  distinct model before promising a cross-model review.

## Skill ownership

| Job | Default owner | Overlapping copy |
| --- | --- | --- |
| React / Next.js performance | Shared `vercel-react-best-practices` | Build Web Apps `react-best-practices` |
| General frontend design | Shared `frontend-design` | Claude frontend-design plugin |
| Screenshot / image implementation | Shared `image-to-code` | Product Design `image-to-code` |
| Figma implementation | Native Figma `figma-design-to-code` when available; shared `implement-design` otherwise | Shared skill is only a fallback |
| Stripe integration | Dedicated Stripe `stripe-best-practices` when available; current official Stripe docs otherwise | Build Web Apps `stripe-best-practices` |
| Delegation and integration | Shared `efficient-frontier` | Provider-specific delegation workflows |
| Problem shaping | Shared `shaping`; `workflows-brainstorm` only saves and hands off the result | Duplicate brainstorming methods |
| General motion decisions | Shared `animate` | Duplicate general animation guidance |
| UI polish | Shared `emil-design-engineering`, including focused polish | Duplicate UI-polish checklists |
| File todo schema, lifecycle, and triage | Shared `file-todos`, including triage mode | Separate triage schema/workflow |
| Source-backed research and implementation documentation | Shared `research`; implementation checks are a reference | Separate docs-first research workflow |

These are ownership choices, not a request to install missing plugins. Resolve
an overlapping recommendation from another workflow to its owner here. Keep
plugin-specific tools, templates, and explicitly requested workflows available.
An explicitly requested installed copy can be re-enabled through the harness's
native controls when needed; disabled copies are not automatically callable.
Check API and dependency versions against the actual project and current
official docs; a version labelled "latest" in a bundled skill can be stale.
For Stripe, load the [shared compatibility reference](research/references/stripe-compatibility.md)
alongside the dedicated plugin. Its corrections are the maintained source for
version and SDK assumptions; leave the plugin's installed files unmodified.

CSS animation, Motion for React, motion accessibility, and motion performance
remain separate implementation and verification specialisms. Planning,
deepening, plan review, and execution also remain distinct stages. Load only
the specialism or stage the task needs.

The Cloudflare and OpenAI `agents-sdk` skills cover different SDKs and remain
separate. Shared authoring guidance also remains distinct from a runtime's
packaging or tool-schema requirements.

## Discovery

The installer exposes the canonical library through `~/.agents/skills` and the
tools' native paths. Codex and Grok both support the neutral path; Grok also
supports Claude compatibility. Use `grok inspect --json` to verify its loaded
instructions, skills, and agents. Its global instruction path is
`~/.grok/AGENTS.md`; keep that linked on hosts without Claude configuration.

Sources: [Codex skills](https://learn.chatgpt.com/docs/build-skills),
[Grok skills](https://docs.x.ai/build/features/skills-plugins-marketplaces),
[Grok instructions](https://docs.x.ai/build/features/project-rules).
